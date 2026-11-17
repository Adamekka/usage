# Usage tracking

Usage is a personal, native macOS menu-bar app.

## App behavior

- Track Codex (OpenAI) and Claude subscription limits side by side, each in its own tab.
- Codex: track the seven-day usage window, the five-hour usage window when returned, and available rate-limit reset
  credits. Read authentication from `~/.codex/auth.json`; never refresh, modify, or store Codex credentials.
- Claude: track the seven-day and five-hour usage windows. Read authentication from Claude Code's
  `Claude Code-credentials` login Keychain item; never refresh, modify, or store Claude credentials. An expired token
  means Claude Code must run again.
- Show both providers in the menu bar, each behind its logo, with five-hour and weekly remaining usage and reset times.
  Keep the label compact: stack the five-hour row above the weekly row, and lead each row with a remaining bar and its
  pace marker. Omit AM/PM from the five-hour reset time, since it is at most five hours away.
- Hide a provider from the menu bar while its latest refresh shows no access: a missing, unreadable, rejected, or
  expired login, or no weekly limit, as after a subscription ends. Its tab still shows the reason. Temporary failures,
  such as network errors, rate limiting, or server errors, keep showing the last values. When no provider has access,
  show "Usage" instead so the menu bar item stays clickable.
- An exhausted window hides its remaining percent but keeps its bar and reset time. While the weekly window is
  exhausted, show only the weekly row for that provider. A window is exhausted when its displayed remaining usage
  rounds to 0%.
- Keep the app out of the Dock and do not add ordinary windows.
- Refresh both providers on launch, every five minutes, and on explicit user request. A failure on one provider does not
  block the other, and a failed refresh keeps the last successful values.

## Usage windows

- Codex: identify the weekly and five-hour windows by duration, regardless of API slot. The five-hour window is
  optional.
- Claude: read the weekly window from `seven_day` and the five-hour window from `five_hour`, where `utilization` is the
  used percent. The weekly window is required; a five-hour window without a reset time has not started and is hidden.
- Remaining usage is `100 - usedPercent`.
- Treat the server-provided reset and expiration timestamps as authoritative.

See [pacing](pacing.md) for usage targets, shared by both providers and both windows.
