# Usage tracking

Usage is a personal, native macOS 26 menu-bar app.

## App behavior

- Track OpenAI's seven-day usage window, its five-hour usage window when returned, and available rate-limit reset
  credits.
- Read authentication from `~/.codex/auth.json`; never refresh, modify, or store Codex credentials.
- Keep the app out of the Dock and do not add ordinary windows.
- Refresh on launch, every five minutes, and on explicit user request.

## Usage windows

- Identify the weekly window by its seven-day duration, regardless of API slot.
- Identify the five-hour window by its duration, regardless of API slot, and treat it as optional.
- Remaining usage is `100 - usedPercent`.
- Treat the server-provided reset and expiration timestamps as authoritative.

See [weekly pacing](weekly-pacing.md) for daily usage targets.
