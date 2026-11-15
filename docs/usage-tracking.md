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

See [weekly pacing](weekly-pacing.md) for daily usage targets, shared by both providers.
