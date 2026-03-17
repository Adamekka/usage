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
- Claude is manual for now.
- GitHub Copilot is manual for now.

## OpenAI

- If needed, sign into Codex with ChatGPT:

```bash
codex
```

- In the app, click `Sync OpenAI`.
- The OpenAI card should show the live short window and weekly window when available.

## Manual Providers

Claude and Copilot only keep the minimum fields needed for the recommendation:

- used
- limit
- reset day

## Troubleshooting

- `Setup`: sign into Codex with ChatGPT.
- `Auth`: your local Codex login likely expired; sign in again.
- `Error`: check your connection, then sync OpenAI again.
