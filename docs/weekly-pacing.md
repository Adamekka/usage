# Weekly pacing

- Offer linear and logarithmic weekly pacing and remember the user's selection. Start with linear pacing.
- Keep the weekly pacing selector compact and directly below the current day's target.
- Targets advance by whole day, where day 1 starts at the beginning of the server-provided window.
- The linear target is `(100 / 7) * currentDay`.
- The logarithmic target is `100 * log(currentDay + 1) / log(8)`, allowing more usage early while keeping some for later.
- Usage above the current day's target is ahead; usage below it is behind.

See [usage tracking](usage-tracking.md#usage-windows) for window identification and authoritative timestamps.
