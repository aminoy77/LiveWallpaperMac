# DeskForge suite — design loop 2 (2026-10-12)

Intent: single app merging live wallpaper + lock video + custom dock + widgets + notch bar.

## Researched (agent-reach / Jina)
- **Widgetter:** desktop overlays — clock/date, HDD/SSD, CPU/RAM/battery, weather, stocks/crypto, calendar, tasks + 4K theme packs.
- **DockFix (€14.99):** full dock replacement — colors/opacity/size/position/animations, custom icons, folders, site shortcuts, presets, file shelf, hover window previews, dock widgets, <1% CPU.
- **MacNotch:** notch hub — dashboard/media/calendar/todo/notes/pomodoro/day-progress/screen-time/weather/notifications/bluetooth/sysmon, drop actions, snap zones, modular toggles, multi-display, no-notch supported.

## Shipped this loop (lean slice, zero new entitlements)
- App shell: MenuBarExtra quick toggles + Settings Window (5 tabs). Binary renamed DeskForge (bundle id kept).
- Widgets: clock / calendar / CPU-MEM-battery (host_statistics, 2s cadence, refcounted sampler shared with notch). Draggable DragPanel above desktop icons.
- Notch: statusBar-level pill + expandable sheet (clock, now-playing via Music public notification + frontmost app, pomodoro, day progress, system line).
- Dock: floating panel, pinned bundleIDs + regular running apps, discrete hover magnify, right-click window titles (CGWindowList, no permission needed), size/opacity/bottom-or-side, native autohide via defaults+killall.
- Lock: poster export (AVAssetImageGenerator 4K JPEG) + set-desktop + Extras/VideoSaver.swift ScreenSaver source reading videoPath bridge key (Engine now saves it).

## Explicitly deferred (say when wanted)
Weather/stocks widgets (API keys), per-icon art + presets + file shelf, live window thumbnails (needs Screen Recording permission), drop actions / snap zones, per-display videos.
