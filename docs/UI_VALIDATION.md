# UI Validation

This revision changes presentation only. Transport, encryption, storage,
models, repositories, and protocol constants retain their pre-redesign hashes.

## Automated Checks

- 18 UI tests plus the existing 40 regression tests.
- Responsive layouts at 320x568, 390x844, 800x600, and 568x320.
- Text scaling at 1.0, 1.5, and 2.0 across eight screen states.
- Long history filenames, device names, and every transfer status.
- Disabled/loading buttons, pause/cancel callbacks, history navigation,
  and device-name editing.
- Idle home schedules no animation frames and has no backdrop filters.
- Rendered-pixel checks and PNG previews for both themes.

Run: `flutter test --no-pub`

Generated previews: `build/ui-preview/`
These are presentation previews, not evidence of physical-device performance.

## Physical Device Checks

1. Install the release APK and check send, receive, history, and settings.
2. Scan the stationary receiver QR with a second phone.
3. Transfer a large file; pause, resume, cancel, and reconnect.
4. Complete a transfer and open the received file.
5. Increase Android font size and rotate the phone; all controls must remain
   reachable by scrolling.
6. Change between dark, light, and system themes; restart as prompted.

The redesign removes decorative perpetual tickers, moving QR overlays,
backdrop blur, shader-masked progress text, and glow shadows. Progress still
animates briefly when its value changes. No transfer-throughput improvement
or measured frame-rate improvement is claimed.

For frame timing on hardware, use `flutter run --profile` and Flutter DevTools.
