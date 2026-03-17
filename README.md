# usage

## Why?

The app is focused on one question: which provider still has room right now?

`usage` is a local-first desktop picker for AI subscriptions.

## Build

- Install dependencies:

```bash
bun install
```

- Run the desktop app:

```bash
bun run tauri dev
```

## Current State

- OpenAI syncs live from your local Codex/ChatGPT sign-in.
- Claude syncs live from your local Claude Code sign-in.
- GitHub Copilot is manual for now.

## OpenAI

- If needed, sign into Codex with ChatGPT:

```bash
codex
```

- In the app, click `Sync OpenAI`.
- The OpenAI card shows the live short window and weekly window.

## Claude

- If needed, sign into Claude Code:

```bash
claude
```

- In the app, click `Sync Claude`.
- The Claude card shows the live session window and weekly window.

## Manual Providers

Copilot keeps the minimum fields needed for the recommendation:

- used
- limit
- reset day

## Troubleshooting

### OpenAI

- `Setup`: sign into Codex with ChatGPT.
- `Auth`: your local Codex login likely expired; sign in again.
- `Error`: check your connection, then sync OpenAI again.

### Claude

- `Setup`: sign into Claude Code (`claude`).
- `Auth`: your local Claude Code session expired; sign in again.
- `Error`: check that the `claude` CLI is installed, then sync Claude again.
