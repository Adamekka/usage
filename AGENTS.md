# Usage Project Preferences

## UI Theme
- Use Dracula theme colors for new UI work unless a specific screen already follows a different established style.

### Dracula Palette
- Background: `#282A36`
- Current Line: `#6272A4`
- Selection: `#44475A`
- Foreground: `#F8F8F2`
- Comment: `#6272A4`
- Red: `#FF5555`
- Orange: `#FFB86C`
- Yellow: `#F1FA8C`
- Green: `#50FA7B`
- Cyan: `#8BE9FD`
- Purple: `#BD93F9`
- Pink: `#FF79C6`

## Implementation Notes
- Prefer defining shared theme values as CSS variables before writing component styles.
- Keep text contrast high against `#282A36` backgrounds.
- Favor compact, information-dense panels over spacious marketing layouts.
- Preserve `ssr = false` for the Tauri shell unless a task explicitly requires changing it.

## Usage Tracker Behavior
- Keep the app local-first unless syncing is explicitly requested.
- The app should answer one question first: which provider still has room right now?
- Prefer provider comparison and recommendation over subscription-management detail.
- Avoid billing, cost, note, and other admin/editor bloat unless the task explicitly calls for it.
- Surface over-limit and near-limit states clearly; do not hide them behind capped progress bars alone.
- For OpenAI, prioritize the short window and weekly window in the main picker UI; treat extra/internal windows as secondary unless explicitly requested.
- Optimize for the owner's personal setup instead of generic multi-user support.
- Prefer existing local auth from installed provider clients when that is easier than adding separate config flows.
