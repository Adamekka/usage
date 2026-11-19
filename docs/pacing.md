# Pacing

- Apply the same pacing rules to the weekly and five-hour windows; they differ only in window duration.
- Offer linear, logarithmic, and exponential pacing and remember the user's selection, shared by both windows. Start
  with linear pacing.
- Keep the pacing selector compact and directly below the current day's weekly target.
- Targets advance continuously, where `elapsedFraction` is the time since the beginning of the server-provided window
  divided by the window duration, clamped to `0...1`.
- The linear target is `100 * elapsedFraction`.
- The logarithmic target is `100 * log(7 * elapsedFraction + 1) / log(8)`, allowing more usage early while keeping some
  for later. Every window is scaled to seven units, so the weekly window follows one unit per day.
- The exponential target is `100 * (8^elapsedFraction - 1) / 7`, the inverse of the logarithmic curve, keeping usage
  low early and saving more for later.
- Weekly day 1 starts at the beginning of the window.
- Usage above the current target is ahead; usage below it is behind.
- Each remaining bar shows a marker at the remaining usage the current target expects, `100 - target`.

See [usage tracking](usage-tracking.md#usage-windows) for window identification and authoritative timestamps.
