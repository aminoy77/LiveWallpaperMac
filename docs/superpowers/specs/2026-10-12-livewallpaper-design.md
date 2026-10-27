# LiveWallpaper for macOS — design (2026-10-12)

Intent: import 4K mp4/mov as wallpaper, all screens, <20MB / ~1% CPU.
Assumes Apple Silicon HW decode (VideoToolbox via AVPlayer).

## Approaches
1. **Native AVPlayer per screen (chosen):** borderless NSPanel at desktop-icon-level-1, AVPlayerLayer resizeAspectFill, hardware decode, zero deps. Rejected alternatives:
2. ScreenSaver framework: deprecated, breaks multi-monitor + Sonoma+.
3. Electron/webview: 300MB+, violates low-resource goal.

## Architecture
- `App.swift`: SwiftUI MenuBarExtra only (no dock icon, LSUIElement).
- `Engine.swift`: 1 AVPlayer + 1 NSPanel per NSScreen; loop via AVPlayerItemDidPlayToEndTime → seek zero; volume shared; security-scoped bookmark persisted.
- Guards: auto-pause on fullscreen + Low Power Mode + screensaver/lock; rebuild on screen-parameter change. Muted default.

## Non-goals
Catalog/store, effects, transcoding, per-display different videos (add when asked).

## Verify
`./build-app.sh` → open `LiveWallpaper.app` → menu bar → Choose 4K Video → check Activity Monitor (CPU/Mem), fullscreen pause, reboot restore.
