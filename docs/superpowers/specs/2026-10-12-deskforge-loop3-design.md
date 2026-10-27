# DeskForge loop 3 — design + postmortem (2026-10-12)

## HIG audit (apple-design, 8 refs)
accessibility, designing-for-macos, settings, widgets, typography, color, the-menu-bar, materials.
Findings applied: clock weights light→regular (`typography.md › Ensuring legibility`: avoid light
weights); ⌘, opens Settings (`settings.md › Best practices`); same-value didSet guards (write-back
churn); semantic colors + ultraThinMaterial only, no custom palette (`color.md`, `materials.md`);
change-sign in markets text, not color alone (`accessibility.md › Vision`); token system: SF only,
material surfaces, black pill signature, monochrome + one accent.

## Stats: root-caused, not patched
- CPU pinned ~100%: old code counted idle ticks as busy (tuple index swap).
- First rewrite (per-CPU processor_info) still pinned: ARM freezes idle ticks (proved: idle delta 0).
- Second rewrite (per-pid sum) read 10–50x low: 60% of pids unreadable (SIP) + pti undercount.
- Final: `host_statistics(HOST_CPU_LOAD_INFO)` aggregate = 0.199 vs `top` ~0.2. MEM formula =
  wired + (internal − purgeable) + compressor (Activity Monitor semantics; old formula counted
  file cache). batt cross-checked vs `pmset`. `--stat-check` ships as permanent proof.

## Crash postmortem (SIGABRT, silent, deterministic)
5 eager @StateObject singletons: 4th in install order died every launch (5/5 runs).
lldb blocked by SIP; bisected with stderr marks + env gates + order swap.
Fix: explicit eager init in `App.init` (dock first) before scenes install. Verified 9/9 + 10s
loaded run. Theory: SwiftUI SceneGraph install-order fragility on macOS 27; deterministic order
holds. Kept as code comment.

## Write-back destructors (found via prefs forensics)
SwiftUI writes control values back on appear; didSet fires even for identical values.
Consequences before guards: `defaults delete com.apple.dock` at launch (userReset), Dock
restarts, panel flashing, sampler churn. Fix: `!= oldValue` guards on every mutating didSet.

## Atoll stack: adopted vs deferred
- Adopted: MediaRemote now-playing via dlopen (any app; fallback = silence), charging bolt,
  Open-Meteo weather (already), hover-expand notch (already), credits/attribution.
- Deferred with reason: SMC temp + IOReport per-core (needs SMCKit port from Stats/MIT —
  next loop with source in hand); SkyLightWindow lock overlay (needs spike); rtaudio visualizer
  (C++ dep, heavy); SwiftTerm tab + LLM tracking (out of scope); Boring.Notch GPL code (copyleft —
  clean-room only); per-icon dock art (breaks signatures); snap zones full (needs AX observers).
