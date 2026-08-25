# Usage Project

## Product

- Usage is a personal, native macOS 26 menu-bar app.
- Track OpenAI's seven-day usage window, its five-hour usage window when returned, and available rate-limit reset
  credits.
- Read authentication from `~/.codex/auth.json`; never refresh, modify, or store Codex credentials.
- Keep the app out of the Dock and do not add ordinary windows or provider abstractions.
- Refresh on launch, every five minutes, and on explicit user request.

## Usage Semantics

- Identify the weekly window by its seven-day duration, regardless of API slot.
- Identify the five-hour window by its duration, regardless of API slot, and treat it as optional.
- Remaining usage is `100 - usedPercent`.
- The whole-day target is `(100 / 7) * currentDay`, where day 1 starts at the beginning of the server-provided window.
- Usage above the current day's target is ahead; usage below it is behind.
- Treat the server-provided reset and expiration timestamps as authoritative.

## Engineering

- Keep the implementation direct and minimal for one user; do not introduce generic service layers or speculative fallback behavior.
