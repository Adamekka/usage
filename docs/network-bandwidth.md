# Network bandwidth

The Network tab shows live download and upload speeds per app, in decimal bytes per second.

- Measure non-loopback TCP and UDP traffic with macOS's built-in `nettop`, without requesting administrator access.
- Sample once per second while the Network tab is visible. Stop monitoring when the tab or menu-bar popover closes, or the app quits.
- Discard the initial lifetime counters. Show the first live sample after approximately two seconds, then update every second.
- Divide each interval's byte deltas by its measured elapsed time.
- Group processes inside an application bundle under that app. Attribute nested helper applications to the outer application.
- Show background services, command-line processes, and processes whose app cannot be identified as separate process rows.
- Show only apps and processes with traffic in the latest sample, sorted by combined download and upload speed.
- Show a retry action if monitoring fails. Include the underlying error in debug builds only.
- Keep no transfer totals or history.

Attribution follows the process information available from macOS. Helpers outside their owning app's bundle may appear as separate processes.
