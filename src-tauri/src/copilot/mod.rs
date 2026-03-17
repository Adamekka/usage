pub mod copilot_quota_snapshot;
pub mod copilot_snapshot;
pub mod copilot_snapshot_status;
pub mod copilot_tracked_subscription;
pub mod copilot_user_payload;

pub use copilot_snapshot::CopilotSnapshot;

use copilot_tracked_subscription::CopilotTrackedSubscription;
use copilot_user_payload::CopilotUserPayload;
use dirs::home_dir;
use reqwest::Client;
use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

const COPILOT_USAGE_URL: &str = "https://api.github.com/copilot_internal/user";

pub async fn fetch_snapshot() -> CopilotSnapshot {
    let auth_path = auth_path_text();

    let token = match load_gh_token() {
        Ok(t) => t,
        Err(msg) => return CopilotSnapshot::needs_auth(auth_path, msg),
    };

    match fetch_usage(&token).await {
        Ok(payload) => process_payload(auth_path, payload),
        Err(msg) if is_auth_error(&msg) => {
            CopilotSnapshot::auth_error(auth_path, strip_error_prefix(&msg))
        }
        Err(msg) => CopilotSnapshot::request_error(auth_path, msg),
    }
}

fn load_gh_token() -> Result<String, String> {
    let gh_binary = gh_binary_path()?;

    let output = Command::new(&gh_binary)
        .args(["auth", "token"])
        .output()
        .map_err(|error| {
            format!(
                "Could not run GitHub CLI at {}: {error}",
                gh_binary.display()
            )
        })?;

    let token = String::from_utf8(output.stdout)
        .map_err(|error| format!("GitHub CLI token returned invalid UTF-8: {error}"))?
        .trim()
        .to_owned();

    if token.is_empty() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        let detail = if stderr.is_empty() {
            String::from("No token returned.")
        } else {
            stderr
        };
        return Err(format!(
            "Sign into GitHub CLI first. Run `gh auth login` to sync Copilot usage. {detail}"
        ));
    }

    Ok(token)
}

async fn fetch_usage(token: &str) -> Result<CopilotUserPayload, String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(15))
        .build()
        .map_err(|error| format!("Could not create an HTTP client: {error}"))?;

    let response = client
        .get(COPILOT_USAGE_URL)
        .header("Authorization", format!("Bearer {token}"))
        .header("Accept", "application/vnd.github+json")
        .header("User-Agent", "usage-tauri")
        .send()
        .await
        .map_err(|error| format!("Could not reach the GitHub Copilot usage endpoint: {error}"))?;

    let status = response.status();

    if !status.is_success() {
        let body_text = response.text().await.unwrap_or_default();

        if status.as_u16() == 401 || status.as_u16() == 403 {
            return Err(format!(
                "AUTH_ERROR: GitHub rejected the Copilot login. Run `gh auth login` again. {}",
                body_text.trim()
            ));
        }

        return Err(format!(
            "GitHub Copilot usage request failed with {}. {}",
            status.as_u16(),
            body_text.trim()
        ));
    }

    response
        .json::<CopilotUserPayload>()
        .await
        .map_err(|error| format!("Could not parse the GitHub Copilot usage response: {error}"))
}

fn process_payload(auth_path: String, payload: CopilotUserPayload) -> CopilotSnapshot {
    let plan = display_plan(payload.copilot_plan.as_deref());

    let premium = match payload
        .quota_snapshots
        .as_ref()
        .and_then(|qs| qs.premium_interactions.as_ref())
    {
        Some(p) => p,
        None => {
            return CopilotSnapshot::request_error(
                auth_path,
                String::from("GitHub Copilot did not return premium request quota data."),
            );
        }
    };

    // Unlimited premium interactions would mean no quota pressure.
    let is_unlimited = premium.unlimited.unwrap_or(false);
    let percent_remaining = if is_unlimited {
        100.0_f64
    } else {
        premium.percent_remaining.unwrap_or(100.0)
    };
    let used_percent = (100.0_f64 - percent_remaining).max(0.0);

    let reset_at = payload
        .quota_reset_date_utc
        .as_deref()
        .and_then(parse_iso_timestamp);

    let entitlement = f64::from(premium.entitlement.unwrap_or(0));
    let remaining = f64::from(premium.remaining.unwrap_or(0));
    let used = if is_unlimited {
        0.0
    } else {
        (entitlement - remaining).max(0.0)
    };

    let subscription = CopilotTrackedSubscription {
        plan: plan.clone(),
        unit: String::from("premium reqs"),
        used,
        limit: entitlement,
    };

    CopilotSnapshot::ready(auth_path, plan, used_percent, reset_at, subscription)
}

fn display_plan(copilot_plan: Option<&str>) -> String {
    match copilot_plan {
        Some("individual") | Some("pro") => String::from("Copilot Pro"),
        Some("pro_plus") => String::from("Copilot Pro+"),
        Some("business") => String::from("Copilot Business"),
        Some("enterprise") => String::from("Copilot Enterprise"),
        Some("free") => String::from("Copilot Free"),
        Some(other) => format!("Copilot {}", title_case(other)),
        None => String::from("GitHub Copilot"),
    }
}

fn parse_iso_timestamp(s: &str) -> Option<i64> {
    chrono::DateTime::parse_from_rfc3339(s)
        .ok()
        .map(|dt| dt.timestamp())
}

fn gh_binary_path() -> Result<PathBuf, String> {
    if let Some(path_env) = std::env::var_os("PATH") {
        for directory in std::env::split_paths(&path_env) {
            let candidate = directory.join("gh");

            if candidate.is_file() {
                return Ok(candidate);
            }
        }
    }

    for candidate in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] {
        let candidate = PathBuf::from(candidate);

        if candidate.is_file() {
            return Ok(candidate);
        }
    }

    Err(String::from(
        "Install GitHub CLI (gh) to sync Copilot usage, or add it to your PATH.",
    ))
}

fn auth_path_text() -> String {
    home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".config")
        .join("gh")
        .join("hosts.yml")
        .display()
        .to_string()
}

fn is_auth_error(message: &str) -> bool {
    message.starts_with("AUTH_ERROR: ")
}

fn strip_error_prefix(message: &str) -> String {
    message.trim_start_matches("AUTH_ERROR: ").to_owned()
}

fn title_case(value: &str) -> String {
    value
        .split(['_', '-', ' '])
        .filter(|segment| !segment.is_empty())
        .map(capitalize)
        .collect::<Vec<_>>()
        .join(" ")
}

fn capitalize(value: &str) -> String {
    let mut characters = value.chars();

    let Some(first) = characters.next() else {
        return String::new();
    };

    format!(
        "{}{}",
        first.to_ascii_uppercase(),
        characters.as_str().to_ascii_lowercase()
    )
}
