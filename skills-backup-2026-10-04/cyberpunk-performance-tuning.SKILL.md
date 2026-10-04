---
name: "cyberpunk-performance-tuning"
description: "Diagnose Cyberpunk 2077 stutter, frame spikes, crashes and shadow/DLSS issues on Ethan's modded setup using RedProfiler captures, logs and the Lua GC tuner."
---

# Cyberpunk performance and stability tuning

Setup: RTX 5090, 3440x1440 @240 Hz HDR, DLSS 4.5 (nvngx 310.9.1, RR Preset F, frame gen 3x), path tracing, ~1,000 mods, ~160 CET mods. Game at `$HOME/mnt/Cyberpunk 2077` via device_bash. Mod files Claude creates go to `C:\Users\wyant\Documents\CET-Cleans` and are installed through Vortex.

## Measure, don't guess
Static code scans ("this mod has onUpdate") mislead. Use **RedProfiler** (Nexus 34223, RCF hub START/STOP). Captures: `red4ext/plugins/RedProfiler/captures/<timestamp>/` (summary.txt, frames.csv, spikes.csv, cet_mods.csv, mods.csv, functions.csv, memory.csv, timeline.csv). Captures can be cumulative; use the newest and note its time vs any mod changes.
- Per-frame cost: `exclusive_ms / frames` from cet_mods.csv and mods.csv.
- Spikes: frames.csv `time_s` deltas > ~22 ms; split by `main_ms` (script) vs not (engine: streaming, NPC spawns).
- Cadence: group spikes.csv rank-1 rows by mod and compute gaps (fixed 1 s / 2 s gaps = Cron timers).
- Lua garbage: memory.csv `lua_alloc_bytes` per mod / duration; timeline.csv ALL rows `lua_heap_kb`; heap drops > 5 MB = GC cycles. Tall spikes that line up with GC drops and are blamed on random mods = Lua GC, not those mods.
- Ask Ethan to stand still in one spot 60-90 s for comparable captures.

## Known fixes in this setup
- **Lua GC stalls (35-80 ms every 12-19 s):** zz_LuaGCTuner v3.2 (CET mod, source + zip in CET-Cleans). Stops Lua GC during gameplay; full collect when game is paused (frozen game clock or TimeSystem.IsPausedState), CET overlay open, or loading; hard cap (default 10240 MB) resumes background GC. Configurable in CET overlay window "Lua GC Tuner" and Settings > MODS (settings.json in its folder). CET's LuaJIT is built GC64 (CET xmake.lua: `openrestry-luajit` gc64=true) so no 2 GB limit. Do NOT use incremental/aggressive GC tuning (made spikes worse), Choom Memory Booster or EXRC alongside it.
- **Advanced Crash Reporter** watch mode stalls threads: `bin/x64/plugins/AdvancedCrashReporter/config.ini` set `[watch] enabled = 0`, `sweep_interval_ms = 60000`, `[modules] scan_interval_ms = 2000`. Backups in `CET-Cleans/AdvancedCrashReporter-config/`. Re-apply after updates.
- **Shadow trailing/flicker:** Ray Reconstruction must be ON; General Shadows Fix caused flicker; Universal Raytraced Player Shadows covers player shadows.
- **Repeated ArchiveXL hair patching** (hair-colour CCXL packs) shows as ResourcePatch bursts in the ArchiveXL log; test by disabling the pack.
- **Menu freeze:** a mod registering ModSettings listeners repeatedly (e.g. Immersive Main Menu Audio).
- Large CET error counts (Lua tracebacks) are worth fixing/removing: check per-mod CET logs.

## Editing deployed files safely
Deployed files are Vortex hardlinks to staging. Edit in place with a Python read-modify-write (`open(p,'r+')`, seek 0, write, truncate) so the link (`stat -c %h` = 2) survives; `sed -i` breaks the link and Vortex may later revert the change. For mods Claude authored, ship a versioned zip to CET-Cleans and have Ethan install it in Vortex instead of patching files. Back up any config before changing it.

## Other quick checks
- DLSS: DLSS indicator registry `HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore ShowDlssIndicator=0x400` (or DLSS Swapper) shows RR preset and FG mode.
- Overlay sensor polling (HWiNFO/Afterburner) can cause fixed-cadence hitches; test with it closed.
- Crowd density affects engine-side spawn hitches.

## Reporting
Lead with the cause and the numbers (ms, cadence, MB/s), then 1-3 concrete actions and a test step. Say what you could not verify.