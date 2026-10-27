# Live Wallpaper for macOS

Lean 4K video wallpaper. Native AVPlayer, no deps, ~150KB binary.

## Run
```
cd LiveWallpaperMac
./build-app.sh
open LiveWallpaper.app
```
Menu bar → **Choose 4K Video…** (.mp4/.mov) → looped on all displays, muted by default.

## Notes
- Volume slider unmutes (muted = lowest CPU).
- Auto-pauses on fullscreen apps + Low Power Mode.
- Video bookmark survives reboot; add the app to Login Items for autostart.
- 4K HEVC (H.265) recommended — hardware-decoded on Apple Silicon.
- `Extras/VideoSaver.swift`: source for a `.saver` bundle that plays your video
  as a screensaver on idle/lock (needs an Xcode ScreenSaver target to build).
