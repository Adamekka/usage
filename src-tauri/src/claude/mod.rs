pub mod claude_auth_status_payload;
pub mod claude_snapshot;
pub mod claude_snapshot_status;
pub mod claude_tracked_subscription;
pub mod claude_usage_window;
pub mod claude_usage_window_kind;

pub use claude_snapshot::ClaudeSnapshot;

use chrono::{DateTime, Datelike, NaiveDateTime, TimeZone};
use chrono_tz::Tz;
use claude_auth_status_payload::ClaudeAuthStatusPayload;
use claude_tracked_subscription::ClaudeTrackedSubscription;
use claude_usage_window::ClaudeUsageWindow;
use claude_usage_window_kind::ClaudeUsageWindowKind;
use dirs::home_dir;
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::str::FromStr;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::time::{Duration, Instant};

const TERMINAL_ROWS: u16 = 40;
const TERMINAL_COLS: u16 = 120;
const CLAUDE_TIMEOUT: Duration = Duration::from_secs(60);
const OUTPUT_POLL_INTERVAL: Duration = Duration::from_millis(100);

enum AuthStatusError {
    NeedsAuth(String),
    AuthError(String),
    RequestError(String),
}

pub async fn fetch_snapshot() -> ClaudeSnapshot {
    match tauri::async_runtime::spawn_blocking(fetch_snapshot_blocking).await {
        Ok(snapshot) => snapshot,
        Err(error) => ClaudeSnapshot::request_error(
            auth_path_text(),
            format!("Claude sync task failed: {error}"),
        ),
    }
}

fn fetch_snapshot_blocking() -> ClaudeSnapshot {
    let auth_path_text = auth_path_text();
    let claude_binary = match claude_binary_path() {
        Ok(path) => path,
        Err(message) => {
            return ClaudeSnapshot::request_error(auth_path_text, message);
        }
    };

    let auth_status = match load_auth_status(&claude_binary) {
        Ok(auth_status) => auth_status,
        Err(AuthStatusError::NeedsAuth(message)) => {
            return ClaudeSnapshot::needs_auth(auth_path_text, message);
        }
        Err(AuthStatusError::AuthError(message)) => {
            return ClaudeSnapshot::auth_error(auth_path_text, message);
        }
        Err(AuthStatusError::RequestError(message)) => {
            return ClaudeSnapshot::request_error(auth_path_text, message);
        }
    };

    let windows = match fetch_usage_windows(&claude_binary) {
        Ok(windows) => windows,
        Err(message) => {
            return ClaudeSnapshot::request_error(auth_path_text, message);
        }
    };

    match ClaudeTrackedSubscription::from_usage(auth_status.subscription_type.as_deref(), &windows)
    {
        Ok(subscription) => {
            ClaudeSnapshot::ready(auth_path_text, auth_status, windows, subscription)
        }
        Err(message) => ClaudeSnapshot::request_error(auth_path_text, message),
    }
}

fn load_auth_status(claude_binary: &Path) -> Result<ClaudeAuthStatusPayload, AuthStatusError> {
    let output = Command::new(claude_binary)
        .args(["auth", "status", "--json"])
        .output()
        .map_err(|error| {
            AuthStatusError::RequestError(format!("Could not run Claude Code auth status: {error}"))
        })?;

    let stdout = String::from_utf8(output.stdout).map_err(|error| {
        AuthStatusError::RequestError(format!(
            "Claude Code auth status returned invalid UTF-8: {error}"
        ))
    })?;
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();

    if stdout.trim().is_empty() {
        let message = if stderr.is_empty() {
            String::from("Claude Code auth status returned no data.")
        } else {
            format!("Claude Code auth status failed: {stderr}")
        };

        return Err(AuthStatusError::RequestError(message));
    }

    let payload = serde_json::from_str::<ClaudeAuthStatusPayload>(&stdout)
        .map(ClaudeAuthStatusPayload::validate)
        .map_err(|error| {
            AuthStatusError::RequestError(format!(
                "Could not parse Claude Code auth status JSON: {error}"
            ))
        })?;

    if !payload.logged_in {
        return Err(AuthStatusError::NeedsAuth(String::from(
            "Sign into Claude Code first. Run `claude auth login` to sync Claude usage.",
        )));
    }

    if payload.auth_method.as_deref() != Some("claude.ai")
        || payload.api_provider.as_deref() != Some("firstParty")
    {
        return Err(AuthStatusError::NeedsAuth(String::from(
            "Claude Code is using API or third-party auth. Sign into Claude Code with your Claude.ai subscription to read plan usage.",
        )));
    }

    if payload.subscription_type.is_none() {
        return Err(AuthStatusError::AuthError(String::from(
            "Claude Code did not report a subscription plan. Run `claude auth login` again.",
        )));
    }

    if !output.status.success() {
        let message = if stderr.is_empty() {
            format!("Claude Code auth status exited with {}.", output.status)
        } else {
            format!("Claude Code auth status failed: {stderr}")
        };

        return Err(AuthStatusError::RequestError(message));
    }

    Ok(payload)
}

fn fetch_usage_windows(claude_binary: &Path) -> Result<Vec<ClaudeUsageWindow>, String> {
    let workspace_path = snapshot_workspace_path()?;
    let pty_system = native_pty_system();
    let pty_pair = pty_system
        .openpty(PtySize {
            rows: TERMINAL_ROWS,
            cols: TERMINAL_COLS,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|error| format!("Could not create a Claude Code terminal: {error}"))?;

    let mut command = CommandBuilder::new(claude_binary.to_string_lossy().into_owned());
    command.cwd(workspace_path);
    command.env("TERM", "xterm-256color");
    command.env("CLAUDE_CODE_SIMPLE", "1");
    command.env("CLAUDE_CODE_DISABLE_TERMINAL_TITLE", "1");

    let mut child = pty_pair
        .slave
        .spawn_command(command)
        .map_err(|error| format!("Could not start Claude Code: {error}"))?;
    drop(pty_pair.slave);

    let master = pty_pair.master;
    let mut reader = master
        .try_clone_reader()
        .map_err(|error| format!("Could not read Claude Code output: {error}"))?;
    let mut writer = master
        .take_writer()
        .map_err(|error| format!("Could not write to Claude Code: {error}"))?;

    let (tx, rx) = mpsc::channel::<Vec<u8>>();

    std::thread::spawn(move || {
        let mut buffer = [0_u8; 8192];

        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(size) => {
                    if tx.send(buffer[..size].to_vec()).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });

    let mut parser = vt100::Parser::new(TERMINAL_ROWS, TERMINAL_COLS, 0);
    let deadline = Instant::now() + CLAUDE_TIMEOUT;
    let mut trust_prompt_handled = false;
    let mut usage_requested = false;

    loop {
        // Drain all chunks that have already arrived before checking the screen.
        // A single recv_timeout starts the wait; any additional buffered chunks
        // are collected immediately without waiting.
        match rx.recv_timeout(OUTPUT_POLL_INTERVAL) {
            Ok(chunk) => {
                parser.process(&chunk);
                while let Ok(more) = rx.try_recv() {
                    parser.process(&more);
                }
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => {}
        }

        let screen = parser.screen().contents();

        if !trust_prompt_handled
            && screen.contains("Quick safety check:")
            && screen.contains("Yes, I trust this folder")
        {
            writer.write_all(b"\r").map_err(|error| {
                format!("Could not confirm Claude Code workspace trust: {error}")
            })?;
            let _ = writer.flush();
            trust_prompt_handled = true;
            continue;
        }

        if !usage_requested && screen.contains("-- INSERT --") && screen.contains('❯') {
            writer
                .write_all(b"/usage\r")
                .map_err(|error| format!("Could not request Claude usage data: {error}"))?;
            let _ = writer.flush();
            usage_requested = true;
            continue;
        }

        if usage_requested {
            if let Ok(windows) = parse_usage_screen(&screen) {
                let _ = child.kill();
                let _ = child.wait();
                return Ok(windows);
            }

            if let Some(message) = usage_error_message(&screen) {
                let _ = child.kill();
                let _ = child.wait();
                return Err(message);
            }
        }

        if Instant::now() >= deadline {
            let _ = child.kill();
            let _ = child.wait();
            let diag = diagnostic_screen(&screen);
            let _ = std::fs::write("/tmp/claude_usage_timeout_screen.txt", &screen);
            let _ = std::fs::write("/tmp/claude_usage_timeout_flat.txt", &diag);
            let preview: String = diag.chars().take(600).collect();
            return Err(format!(
                "Claude usage did not load in time (60s). Flat screen: {preview}"
            ));
        }
    }
}

fn parse_usage_screen(screen: &str) -> Result<Vec<ClaudeUsageWindow>, String> {
    // Flatten the entire screen into a single string with spaces between rows,
    // then split on the known section headers. This is more robust than
    // per-line matching because vt100 cursor movements can scatter characters
    // across multiple cells on the same or adjacent rows.
    let flat = flat_screen(screen);

    let Some(session_window) = parse_usage_section_flat(
        &flat,
        "Current session",
        "Current week (all models)",
        ClaudeUsageWindowKind::Session,
    ) else {
        return Err(String::from("Claude session usage is still loading."));
    };
    let Some(weekly_window) = parse_usage_section_flat(
        &flat,
        "Current week (all models)",
        "Extra usage",
        ClaudeUsageWindowKind::Weekly,
    ) else {
        return Err(String::from("Claude weekly usage is still loading."));
    };

    Ok(vec![session_window, weekly_window])
}

/// Collapses the screen into a single whitespace-normalised string, then
/// extracts the slice between two header markers and parses it.
fn parse_usage_section_flat(
    flat: &str,
    header: &str,
    next_header: &str,
    kind: ClaudeUsageWindowKind,
) -> Option<ClaudeUsageWindow> {
    let start = flat.find(header)? + header.len();
    let end = flat[start..]
        .find(next_header)
        .map(|i| start + i)
        .unwrap_or(flat.len());
    let slice = &flat[start..end];

    let used_percent = used_percent_from_flat(slice)?;
    let reset_at = parse_reset_from_flat(slice);

    Some(ClaudeUsageWindow::new(
        kind,
        section_label(kind),
        used_percent,
        reset_at,
    ))
}

/// Joins all non-empty screen rows with a space, collapsing internal whitespace
/// within each row. This survives vt100 cursor-right gaps and stray escape
/// prefix characters on the first row.
fn flat_screen(screen: &str) -> String {
    screen
        .lines()
        .map(|line| line.split_whitespace().collect::<Vec<_>>().join(" "))
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

fn used_percent_from_flat(slice: &str) -> Option<f64> {
    // Look for "N% used" or "N.M% used" anywhere in the slice.
    let suffix_index = slice.find("% used")?;
    let prefix = &slice[..suffix_index];
    let number: String = prefix
        .chars()
        .rev()
        .take_while(|c| c.is_ascii_digit() || *c == '.')
        .collect::<String>()
        .chars()
        .rev()
        .collect();

    number.parse::<f64>().ok()
}

fn parse_reset_from_flat(slice: &str) -> Option<i64> {
    let lower = slice.to_ascii_lowercase();

    // Primary path: literal "resets " present (works for weekly absolute dates
    // like "Resets Mar 20 at 1pm (Europe/Prague)").
    if let Some(start) = lower.find("resets ") {
        let rest = &slice[start..];
        let end = rest
            .find(" Current ")
            .or_else(|| rest.find(" Extra "))
            .unwrap_or(rest.len());
        if let Some(ts) = parse_reset_line(&rest[..end]) {
            return Some(ts);
        }
    }

    // Fallback: the session reset text is fragmented by cursor-right escapes
    // into "Rese s 3 m (Europe/Prague)" so "resets " never appears as a
    // substring.  Scan the token list for a number followed by "m" or "h".
    parse_relative_reset_duration(slice)
}

/// Scans whitespace-split tokens for "N m" / "N h" / "N h N m" patterns and
/// returns `now + duration` as a Unix timestamp.  Only the unit tokens "m" and
/// "h" (isolated, not glued to a number like "1pm") are matched, so progress
/// bar percentages ("23%") and time-of-day strings ("1pm") are safely ignored.
fn parse_relative_reset_duration(slice: &str) -> Option<i64> {
    let tokens: Vec<&str> = slice.split_whitespace().collect();
    let mut total_seconds: i64 = 0;
    let mut found = false;
    let mut i = 0;

    while i < tokens.len() {
        if let Ok(n) = tokens[i].parse::<i64>() {
            let next = tokens.get(i + 1).copied().unwrap_or("");
            match next {
                "m" | "min" => {
                    total_seconds += n * 60;
                    found = true;
                    i += 2;
                    continue;
                }
                "h" | "hr" => {
                    total_seconds += n * 3600;
                    found = true;
                    i += 2;
                    continue;
                }
                _ => {}
            }
        }
        i += 1;
    }

    if found {
        Some(chrono::Utc::now().timestamp() + total_seconds)
    } else {
        None
    }
}

fn section_label(kind: ClaudeUsageWindowKind) -> String {
    match kind {
        ClaudeUsageWindowKind::Session => String::from("Session"),
        ClaudeUsageWindowKind::Weekly => String::from("Week"),
    }
}

fn usage_error_message(screen: &str) -> Option<String> {
    let flat = flat_screen(screen);
    let lower = flat.to_ascii_lowercase();

    if lower.contains("failed to load usage") || lower.contains("could not load usage") {
        return Some(flat);
    }

    if lower.contains("unknown skill: usage") {
        return Some(String::from(
            "This Claude Code build could not open the local /usage dialog.",
        ));
    }

    None
}

fn diagnostic_screen(screen: &str) -> String {
    flat_screen(screen)
}

/// Parses a Claude CLI reset line like "Resets Mar 20 at 1pm (Europe/Prague)"
/// into a Unix timestamp. Returns None if parsing fails — the frontend will
/// just omit the relative countdown rather than crash.
fn parse_reset_line(line: &str) -> Option<i64> {
    // Strip leading "Resets " (case-insensitive).
    let rest = line.trim().strip_prefix("Resets ")?.trim();

    // Extract timezone name from parentheses at the end: "... (Europe/Prague)"
    let (date_part, tz_name) = if let (Some(open), Some(close)) = (rest.rfind('('), rest.rfind(')'))
    {
        if open < close {
            let tz = rest[open + 1..close].trim();
            let date = rest[..open].trim();
            (date, tz)
        } else {
            (rest, "UTC")
        }
    } else {
        (rest, "UTC")
    };

    let tz: Tz = Tz::from_str(tz_name).ok()?;
    let now_in_tz: DateTime<Tz> = chrono::Utc::now().with_timezone(&tz);

    // Formats produced by Claude CLI:
    //   "Mar 20 at 1pm"       — absolute date + time
    //   "Mar 20 at 1:30pm"    — absolute date + time
    //   "3am" / "3:30am"      — bare time-of-day (session window, resets today or tomorrow)
    let naive = if date_part.contains(" at ") {
        parse_month_day_time(date_part, now_in_tz.year())?
    } else {
        // Bare time: interpret as the next occurrence of that clock time in the
        // given timezone (today if still in the future, tomorrow if already past).
        parse_time_of_day_next(date_part, &now_in_tz)?
    };

    // Interpret the naive datetime in the given timezone.
    let dt = tz.from_local_datetime(&naive).earliest()?;

    Some(dt.timestamp())
}

/// Parses a bare time string like "3am" or "3:30am" and returns the next
/// NaiveDateTime that represents that time in the given timezone — today if
/// the time hasn't passed yet, otherwise tomorrow.
fn parse_time_of_day_next(time_str: &str, now: &DateTime<Tz>) -> Option<NaiveDateTime> {
    let (hour, minute) = parse_12h_time(time_str.trim())?;
    let today = now.date_naive();
    let candidate = today.and_hms_opt(hour, minute, 0)?;

    // If the candidate is in the past (in the tz), roll forward to tomorrow.
    let candidate_dt = now.timezone().from_local_datetime(&candidate).earliest()?;

    if candidate_dt <= *now {
        let tomorrow = today.succ_opt()?;
        tomorrow.and_hms_opt(hour, minute, 0)
    } else {
        Some(candidate)
    }
}

fn parse_month_day_time(s: &str, year: i32) -> Option<NaiveDateTime> {
    // Split on " at " to separate date from time.
    let (date_str, time_str) = s.split_once(" at ")?;
    let date_str = date_str.trim();
    let time_str = time_str.trim();

    // Parse "Mar 20" — month abbreviation + day.
    let mut parts = date_str.split_whitespace();
    let month_str = parts.next()?;
    let day_str = parts.next()?;

    let month = month_abbrev(month_str)?;
    let day: u32 = day_str.parse().ok()?;

    // Parse "1pm" / "1:30pm" / "10am".
    let (hour, minute) = parse_12h_time(time_str)?;

    chrono::NaiveDate::from_ymd_opt(year, month, day)?.and_hms_opt(hour, minute, 0)
}

fn month_abbrev(s: &str) -> Option<u32> {
    match s {
        "Jan" => Some(1),
        "Feb" => Some(2),
        "Mar" => Some(3),
        "Apr" => Some(4),
        "May" => Some(5),
        "Jun" => Some(6),
        "Jul" => Some(7),
        "Aug" => Some(8),
        "Sep" => Some(9),
        "Oct" => Some(10),
        "Nov" => Some(11),
        "Dec" => Some(12),
        _ => None,
    }
}

fn parse_12h_time(s: &str) -> Option<(u32, u32)> {
    let lower = s.to_ascii_lowercase();
    let is_pm = lower.ends_with("pm");
    let is_am = lower.ends_with("am");

    if !is_pm && !is_am {
        return None;
    }

    let digits = &lower[..lower.len() - 2];

    let (hour, minute) = if let Some((h, m)) = digits.split_once(':') {
        (h.parse::<u32>().ok()?, m.parse::<u32>().ok()?)
    } else {
        (digits.parse::<u32>().ok()?, 0)
    };

    let hour_24 = match (hour, is_pm) {
        (12, false) => 0,    // 12am → 0
        (12, true) => 12,    // 12pm → 12
        (h, true) => h + 12, // 1pm–11pm → 13–23
        (h, false) => h,     // 1am–11am → 1–11
    };

    if hour_24 > 23 || minute > 59 {
        return None;
    }

    Some((hour_24, minute))
}

fn auth_path_text() -> String {
    auth_path().display().to_string()
}

fn auth_path() -> PathBuf {
    home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".claude.json")
}

fn snapshot_workspace_path() -> Result<PathBuf, String> {
    let workspace_path = home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".claude")
        .join("usage-status");

    fs::create_dir_all(&workspace_path).map_err(|error| {
        format!(
            "Could not create the Claude usage workspace at {}: {error}",
            workspace_path.display()
        )
    })?;

    Ok(workspace_path)
}

fn claude_binary_path() -> Result<PathBuf, String> {
    if let Some(path) = std::env::var_os("CLAUDE_BINARY") {
        let path = PathBuf::from(path);

        if path.is_file() {
            return Ok(path);
        }
    }

    if let Some(path_env) = std::env::var_os("PATH") {
        for directory in std::env::split_paths(&path_env) {
            let candidate = directory.join("claude");

            if candidate.is_file() {
                return Ok(candidate);
            }
        }
    }

    for candidate in ["/opt/homebrew/bin/claude", "/usr/local/bin/claude"] {
        let candidate = PathBuf::from(candidate);

        if candidate.is_file() {
            return Ok(candidate);
        }
    }

    Err(String::from(
        "Install Claude Code CLI to sync Claude usage, or set CLAUDE_BINARY to its path.",
    ))
}
