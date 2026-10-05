# Cyberpunk 2077 modding — handoff from Cowork session (2026-10-03)

> Folder renamed Oct 4: Documents\CET-Cleans -> Documents\cyberpunk-mod-patches (patch backups, custom mods, source).

## Setup
- Patch 2.31 (game 3.0.80). Vortex profile "NCR Core 2.31a". Plays Fem V.
- RTX 5090, Ryzen 7 9800X3D, 64 GB RAM, 3440x1440 @ 240 Hz, HDR, path tracing, DLSS 4.5 (frame gen x2).
- Paths (Windows):
  - Game: C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077
  - Vortex staging folder: the "mods" folder Vortex uses (the deployment manifest is vortex.deployment.json in the game root)
  - Backups and custom mods: C:\Users\wyant\Documents\cyberpunk-mod-patches
  - Another agent's audit: C:\Users\wyant\Downloads\cet-cleanup\CET Mod Audit.html

## Ground rules
- Install and remove everything through Vortex. Deployed files are hardlinks into staging.
  - Editing in place with `sed -i` breaks the link, and Vortex reverts the file.
  - To change a deployed file: edit it in place (read-modify-write), or ship a zip and install it through Vortex.
- Save custom mod files and config backups to cyberpunk-mod-patches.
- Never store or repeat API keys or tokens seen in logs (Nexus key, RedHttpClient bearer token).
- Downloads and installs need Ethan's OK.
- Saved skills you can use: cyberpunk-mod-audit, nexus-mods-via-chrome, cyberpunk-performance-tuning.

## SOLVED (Oct 3, 17:46): crash on load in NCA persistence
- Cause: the "Night City Allies - AIO (redscript only)" 1.6.2 build was deployed. Fix: replaced with the full AIO 1.6.9 (Vortex folder "Night City Allies - AIO 27625 1.6.9 ..."). Saves written at 17:50–17:51 load fine.
- No mod uses `@addField` on NCA structs (grep of staging + deployed r6/scripts on Oct 4 found none). Don't reinstall the redscript-only build.
- The notes below are kept for history only.

## (historical) crash on load after adding a batch of mods (Oct 3, ~17:00–17:30)
- ACR reports are in bin\x64\plugins\AdvancedCrashReporter\reports\, 6 crashes from 17:33 to 17:40. They take two forms:
  - EXCEPTION_STACK_OVERFLOW from endless recursion of `PackageObjectSerializer::OnReadValue` → `HandlePropertyMissing` → ScriptableSystem construction.
  - ACCESS_VIOLATION in memcpy from `PackageReadStream::OnRead`, reached through the same HandlePropertyMissing chain.
- Full path in the latest two crashes: `ScriptableSystemsContainer::OnGameLoad` → `CreateAndAttachAllSystems` → `PackageInspector::ReadObject` → object → **array** → object → HandlePropertyMissing (nested).
- ACR names **NightCityAllies.Persistence.PersistenceSystem** as the object.
  - This class holds persistent `array<struct>` registries: CompanionModData, ConversationProgression, NCATimerData, CommpanionOutfit, NCACompanionEquipment(Part), StaticModData.
- Meaning: the game is deserializing **save data** for NCA, and a struct element in the save has a property the current definition lacks. The engine fails to skip it.
  - It is not a file conflict, and no mod code is on the stack.
  - It happens about 1:20–1:50 after launch, while a save is loading.
- Ruled out:
  - NCA 1.6.2 itself is unchanged (files dated Sep 6–7, same archive).
  - Ethan already disabled most of the new redscript mods: JackedIn, HackTheCorps, SmugglersCache, World Builder 1.0.81, CyberdeckWearable, AnimatedWidgets, SmasherEncounters, TraumaTeamMedic/Sandevistan, sonoraapex, More Inventory Filters, E3 Smart Windows. It still crashes in NCA persistence.
- Leading hypotheses:
  1. A mod that is now removed added persistent fields to NCA structs with `@addField`, so the save holds those fields. Candidates:
     - EdgerunnersMansionForNightCityAllies (removed Oct 2; its r6/scripts folder is empty)
     - Mai Hasegawa / NCA add-ons: Aerial Drones and Androids Faction (27769), which deploy into NightCityAlliesModules
     - Second Heart Combat Fix (removed; Mai Hasegawa requires it; Ethan should reinstall it)
     - Next step was interrupted: grep the staging folder and any re-downloaded archives for `@addField(CompanionModData|...|PersistenceSystem)`.
  2. The save was written by a different NCA version or layout.
- Tests to run:
  - Start a new game, or load a save from before the Oct 2 removals. If that loads, the save is the problem.
  - Temporarily reinstall the removed NCA add-ons/mansion, load the save, and re-save.
  - Bisect what was removed, not only what was added.
- Other noise in the logs (not the cause):
  - ArchiveXL "Patch resource dedaline/all.streamingblock failed to load" (from the Dedra mods).
  - Mod Settings keybind warnings (NitroBoost, GarageCore).
  - TweakXL rejects TraumaV `gamedataPlayerGenderPrereq_Record` equipPrereqs and `visibilityPrereqs`.
- Batch added Oct 3:
  - About 60 apartment, prop and world mods (Japantown North, Santo Domingo, Pacifica Beach House/pier, Kabuki, Glen Project, Palapas, Charter Hill, Longshore, B1 homes, Mansion Reloaded, Use Your Fridge, prop packs). These are mostly archive/AMM files.
  - Redscript mods: HackTheCorps, CyberdeckWearable (Wear Your Deck), JackedIn, SmugglersCache, SmasherEncounters, AnimatedWidgets, World Builder 1.0.81, Sonora Apex, Extra Vendors, TraumaTeamMedic, Trauma helmets/inhaler, FindMyRide, DesoPierreAmmoExpanded.
- Redscript name clash to note: `TutorialSystem extends ScriptableSystem` is defined in both ChipwareExpansion and NightlyNow (JackedIn also had one). This is not the crash cause, but it is a risk.

## Solved so far (don't redo)
- Shadow flicker: caused by General Shadows Fix (removed).
- Courier Jobs datajack bug: duplicate Courier Jobs install.
- Advanced Crash Reporter stalls: low-overhead config (`[watch] enabled=0`, `sweep_interval_ms=60000`, `[modules] scan_interval_ms=2000`). Backups are in cyberpunk-mod-patches\AdvancedCrashReporter-config\.
- **Periodic frame spikes = Lua GC stalls in CET's shared LuaJIT state.** Found with RedProfiler (34223); spikes line up with lua_heap drops. Fixed by my CET mod **zz_LuaGCTuner v3.2**:
  - Stops GC during gameplay. Collects fully when paused or in menus (pause detected from a frozen game timestamp). Hard cap 10 GB triggers a GC restart.
  - Has an ImGui window and a Native Settings tab.
  - Source and zip are in cyberpunk-mod-patches (zz_LuaGCTuner-source\, zz_LuaGCTuner-v3.2.zip).
  - Ethan needs to install the v3.2 zip through Vortex, because Vortex reverted the deployed copy to v3.
  - His menu-collect threshold is 1015 MB. Recommend about 150–300 MB, since a full collect costs about 1 ms/MB.
  - Notes: CET's sandbox exposes `collectgarbage` but not `jit`. JIT is only on/off (config.json developer.enable_jit). The LuaJIT build is GC64. Choom Memory Booster and EXRC were tried and made things worse.
- TraumaV armor recognized by Chrome Plating (reads DigitalVixen Core ItemFacts): added r6\storages\DigitalVixenCore\itemfacts.user.json:
  - ash_trauma_armor_01 = medium, 100
  - _02 and _03 = heavy, 250
  - Values are based on Zenitex. Backup is in cyberpunk-mod-patches\DigitalVixenCore-itemfacts\.
  - Flesh & Chrome does stamina only, not armor.
- Trauma Team mod audit: claude.ai artifact PtpbpE7VWN8oXo6duaX4zM. TraumaTeamCorpo = keep (Deep Scan works). Second Heart Combat Fix = keep/reinstall.

## Local mansion patches (Oct 3, not uploaded - licenses forbid it)
- NCA-MansionReloaded-v1.1.zip (replaces v1.0): port of DrayStation's NCA mansion add-on (33561 v1.0.1) to Mansion Reloaded (26023). Transform fitted on 141 identical meshes (3 cm) between the vanilla mansion interior sector and MansionReloaded.streamingsector: rotate -87.2366 deg about Z, shift (-3590.7434, -1290.7410, -78.3474). v1.0 used -90 deg from interaction spots and was off ~0.6-1 m (Ethan saw a uniform offset).
- MansionDLC-Fixes-v1.1.zip: fixes for the original mansion (5437). (1) Elevator: patch 2.x put two weapon vending machines in the street-elevator doorway (exterior_-22_17_0_0 nodeData 705/709 + LOD proxies exterior_-11_8_0_1 247/250); zz_mansionDLC_2x_elevator_fix.xl deletes them via ArchiveXL. (2) Performance: per-frame and 1 s work only within 200 m of the mansion or elevator shaft (overrides mansionDLC init.lua + modules/logic.lua; set to load after 5437). The mod's full override of interior_-42_37_3_0 only lowers one vanilla coffee machine 2 m, otherwise identical to 2.31.
- MansionDiag-v1.0.zip (only needed if the elevator still misbehaves): temporary CET hotkey "Dump mansion devices" -> MansionDiag.log. Used to find the new IDs of the elevators and doors that 5437 hard-codes (likely cause of the "wall instead of elevator" bug). Remove after.
- Next (lower priority): auto-generate NCA location modules for the other apartments from their Native Interactions project JSONs.

- DroneCompanion-LootThrottle-v1.0.zip: overrides DroneCompanion init.lua + loot.lua (load after Drone Companion). Android auto-loot scan every 5 s (was 2 s) and skipped for up to 15 s while standing still after an empty scan. Cause measured Oct 3: loot.tick ~1.8 ms avg / 8 ms max every 2 s (60 m targeting query + up to 500 tracked containers).

- smartWindow-Throttle-v1.0.zip: overrides smartWindow init.lua (load after smartWindow). Window check twice a second with cached entEntityIDs; it created ~300k objects per 23 min, held until Lua GC.
- zz_LuaGCTuner settings changed Oct 3 23:0x: menuCollectMB 1015 -> 300, hardCapMB 10240 -> 2048 (backup in zz_LuaGCTuner-settings-backup). Reason: 23-min capture showed the Lua heap at 4.3 GB before a collect, and the 23:00 crash report showed commit at 74.2/78.7 GB (page file only 3.9 GB).
- Crash 2026-10-03 23:00: access violation in anim::AnimNode_SkAnim::OnGatherSyncData (engine animation graph, no mod on stack) while in Mansion Reloaded with NCA companions. Not attributed; watch for repeats.

- MansionDLC-Fixes-v1.2.zip (replaces v1.1): adds guards to the 4 workspot files: each workspot registered its own PlayerPuppet.OnAction observer (~50 Lua calls/frame citywide, 0.2 ms/frame, ~0.66 MB/s garbage); now returns immediately unless V is in that workspot.
- zz_LuaGCTuner-v4.0.zip (source in zz_LuaGCTuner-source-v4): second collect in the same pause when the first leaves the heap well above the live set (finalizer userdata need two cycles), and no cleanup unless the heap grew >= 64 MB since the last one. Measured Oct 3: live set ~240 MB = ~200 ms per full pass; total Lua garbage 5.9 MB/s (mansionDLC 0.66, NIF 0.60, 0-Engine 0.39, DroneCompanion 0.38, marmurbank 0.27).
- Ethan set the tuner to menuCollectMB 850 / hardCapMB 10240 himself (23:29) - keep unless he asks.

- Garbage-at-source patches (Oct 4, all Vortex overrides, load after the original mod; Lua, not compile-testable offline):
  - NativeInteractions-DistanceGate-v1.0: projectsManager.update runs far interactions (> max(80 m, reset/animation distance + 10)) once a second, staggered.
  - 0-Engine-StateThrottle-v1.0: player blackboard/position/derived state at 30 Hz (dependents use timers >= 0.1 s); Proximity/SpatialHash/frame emitters stay per-frame (they modulo on frame number).
  - marmurbank-InputGuard-v1.0: cheap suppress/hub check before building action-name strings in its PlayerPuppet.OnAction Override + Observe.
  - yaibaPenthouse-DistanceGate-v1.0: bathtub/lamp/candle updates at 2 Hz beyond 150 m of (-1160.27, 1579.75, 75.74).
  - DedkaAutoShop-DrawFix-v1.0: onDraw no longer creates a closure every frame.
  - Left alone: DroneCompanion input.lua Override (needs every action name for its keybinds).

- InputHints-TallPanel-v1.0.zip (FAILED 2026-10-04: hid the right-side hint list completely; disable it in Vortex. The game sizes/places hints from the 50-tall Root canvas, so enlarging it pushes the list off-screen. Next idea: find the HUD slot / controller that clips it rather than resizing the library item): overrides base\gameplay\gui\widgets\input_hints\input_hints.inkwidget with the Root canvas 300x50 -> 300x1400 (built with WolvenKit CLI serialize/deserialize/pack). Aim: stop long mod hint lists (Drive an Aerial Vehicle etc.) being cut off at the top. Alternative cause to rule out: quest tracker (QuestWidget_RightAligned) covering the list - test by untracking the quest.

- MansionDLC-Fixes-v1.3.zip (replaces v1.2): also skips the BaseMappinBaseController.UpdateRootState pin hook when far from the mansion (world.near set by logic.checkInRange).

## Redscript rule learned (Oct 3)
- This redscript build cannot annotate classes defined in another mod's scripts: @addMethod crashes the compiler ("constant pool error: definition not found"), @wrapMethod/@replaceMethod give UNRESOLVED_METHOD. Annotate only game classes; to change another mod, patch its source file and ship it as a Vortex override.
- SmasherEncounters_LiveSettings 1.0/1.1 never compiled for this reason - keep them uninstalled. Replacement: SmasherEncounters_Patched-v2.0.zip (patched SmasherEncounters.reds for 2.4; overrides the original file, load after Smasher Encounters). Builder: SmasherEncounters_LiveSettings-source-v2.0\make_patched.py (re-run on a new Smasher version).
- Offline compile check: engine	ools\scc.exe -compile <scripts dir> -customCacheDir <dir with a copy of r6\cacheinal.redscripts>. Include red4ext\plugins\mod_settings\packed.reds and Codeware\Scripts for dependencies.

## TODO later: Mansion Reloaded NCA port (Ethan parked it Oct 3, using the original mansion for now)
- v1.1 placement is close. Remaining: the two stand_rail spots (Panam ~0.5 m short of the glass, Lucy standing on the rail base) - Reloaded moved/rebuilt those railings; nudge individually (get positions via CET console print(GetPlayer():GetWorldPosition()) or NCA Editor markers).
- Companions walk through walls: Reloaded has no navmesh. Mitigate with NCA Path() waypoints through doorways (kitchen<->balcony, up<->downstairs).
- Pool spots not verified. Tools: scratch scripts port_nca.py / meshfit.py logic is described in NCA-MansionReloaded	ransform.json.

## cyberpunk-mod-patches cleanup (Oct 4)
- Sent to Recycle Bin (restorable): MansionDLC-Fixes v1.1/v1.2 zips, NCA-MansionReloaded v1.0 zip, SmasherEncounters_LiveSettings 1.0/1.1 zips + their two old source folders, zz_LuaGCTuner test/v2-rare/v3-menu zips, MansionDiag (folder + zip), DroneCompanion-backup. Mentions of those files above are historical.
- Current: MansionDLC-Fixes-v1.3, NCA-MansionReloaded-v1.1, SmasherEncounters_Patched-v2.0 (source-v2.0), zz_LuaGCTuner-v4.0 (v3.2 zip + source kept as fallback until v4 is tested), plus the v1.0 patches (DroneCompanion-LootThrottle, smartWindow-Throttle, NativeInteractions-DistanceGate, 0-Engine-StateThrottle, marmurbank-InputGuard, yaibaPenthouse-DistanceGate, DedkaAutoShop-DrawFix, InputHints-TallPanel).

## Goals going forward
- Fix the load crash above.
- Keep paring down CET (Lua) overhead and runtime polling. Prefer redscript editions of mods where they exist.
- **Drone Companion is the #1 must-keep mod.** Its 1 s watchdog in companion.lua (`watchdogTick` → `records.stockSignature`) is moderate overhead. Options: a throttle patch, or a report to the author.
- Mods that spam errors (fix or remove):
  - smartWindow
  - Missing Persons Messenger error
  - Pacifica Typhoon
  - Cyber Heart
  - Sandevistan/SmartLink
  - Radio Port Vehicle Fix
- Advice already given:
  - Disable MovementAndCameraTweaks (4039) in favor of TFPC movement tweaks. This fixes first-person body clipping and the camera snapping up when looking down.
  - Use one death-rescue system: Coverage, not the Cyber Heart implant.
  - Keep Orthrus over Hellhound/Man-O-War.
  - Keep Mod Configuration Menu (it unifies the other menus).
  - Turn off the Minimap Widgets FPS widget.
- Optional: add helmet/shoulder ItemFacts rows for TraumaV armor.

## zz_LuaGCTuner v5.0 (2026-10-04, zip + zz_LuaGCTuner-source-v5; v4.0 zip kept as fallback until v5 is tested)
- Red center-screen warnings (PlayerPuppet:SetWarningMessage) at 90/95/99% of the hard cap; re-arm below 85%.
- Menu cleanup threshold max = 90% of the hard cap (clamped).
- At 100% in gameplay: "memory FULL ... expect a large stutter (~N s)" message, full cleanup 1 s later (estimate from last measured ms/MB). If the cap is below the live set, falls back to background GC with a "raise the cap" message.
- Hard cap 0-128 GB, unit GB/MB selectable; 0 = no cap. Exact typing in the CET overlay; Native Settings sliders (0.05 GB / 16 MB steps) rebuild after the settings page closes.
- Settings at build time: menuCollectMB 2000, hardCapMB 16384 (Ethan's). settings.json is not in the zip.

## zz_LuaGCTuner v5.1 (2026-10-04; supersedes v5.0 once tested)
- Pause cleanups wait `pauseWaitS` (default 2 s, 0-10) so the freeze misses the pause transition. Suspected cause of the audio breaking after pause (12:05:33: 1.1 s cleanup right as Ethan paused after a Marmur text; earlier 2.7-4.6 s freezes).
- Per-menu triggers: Esc pause menu / map / inventory & character / journal & messages / other pauses / CET overlay (MenuScenario_PauseMenu + MenuScenario_HubMenu OnOpenMenu name). Loading always cleans.
- "Clean up Lua memory now" CET hotkey (warning popup, cleanup 1 s later).
- Native Settings Apply button rebuilds the page live (deferred one frame); subcategories removed last-first.

## Crash 2026-10-04 12:19 (loading a save at the mansion, [-1382,1270,124])
- redDispatcher6 access violation in SimpleOccupantSlotSpawner::PrepareOccupantsConfig -> TweakDB Val<DynArray<CName>> on a RandomPassengerEntry, police Emperor (entity replaced by ncpd_fleet.archive). Police passenger records (NightCityTrafficOverhaul / FactionsEvolved) look valid; only TweakXL warning is Vehicle.aldecaldos__modded_arch_vigil_gray.randomPassengers (missing record). Treated as one-off; if it repeats, suspect ncpd_fleet + NCTO + FactionsEvolved police vehicle overlap. Page file still 4 GB (commit 62.3/73.2 GB).

## zz_LuaGCTuner v5.2 + SysMemInfo v1.0 (2026-10-04)
- SysMemInfo (own RED4ext plugin) is Rust: SysMemInfo-rs (red4ext-rs v0.9.1 from git + windows-sys). Build in PowerShell: $env:LIBCLANG_PATH='C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin'; $env:CMAKE_GENERATOR='Visual Studio 17 2022'; cargo build --release (the VS 18 BuildTools generator fails). SysMemInfo-source (C++) is the superseded first build. Ethan prefers Rust for native plugins. Global natives returning Float MB: SysMem_AvailPhysMB, SysMem_TotalPhysMB, SysMem_AvailCommitMB, SysMem_CommitLimitMB, SysMem_ProcessCommitMB (CET: Game.SysMem_AvailPhysMB()).
- Tuner v5.2: pause wait 0-180 s default 10 (typeable in CET overlay); cleanup-result notices queued and shown back in gameplay; Native Settings "Clean up now" button (key: CET overlay > Bindings); dynamic hard cap = Lua heap + min(free RAM, free commit) - reserve (default 8 GB), min 2 / max 64 GB, checked every 5 s, ignores moves < 256 MB, notice when it moved >= dynNotifyGB.
- Ethan's UI is Mod Configuration Menu over Native Settings: changes need MCM's APPLY before our buttons run ("Apply or revert pending changes").
- GC cannot be threaded: LuaJIT GC runs on the thread that owns the shared CET Lua state (main thread).
- v5.2 final: Native Settings page refreshes itself 0.5 s after hard cap unit/value changes (works with MCM's bottom APPLY); the separate in-page Apply button was removed. Warning lead time setting (default 3 s) before hard-cap/hotkey cleanups.

## zz_LuaGCTuner v5.3 (2026-10-04) - current
- Single zip: CET mod + red4ext/plugins/SysMemInfo/SysMemInfo.dll (Rust). Standalone SysMemInfo-v1.0.zip removed; if it was installed in Vortex, uninstall it (same file path).
- "Clean up now key" in Native Settings / MCM (addKeyBinding, cfg.cleanKey, default IK_None) read via Codeware CallbackSystem 'Input/Key' proxy; only IACT_Press during gameplay. CET hotkey still registered.
- Dynamic cap section replaced by an explanation subcategory when the plugin is missing (probe gives up after 3 failed reads to avoid CET error spam).
- v5.4: menu countdown ('Lua memory cleanup in N s (size, ~freeze)') drawn with CET ImGui at top-center while paused in a menu that will clean up; the cleanup runs one frame after 'Cleaning up...' is drawn. Toggle: menuCountdown (default on). Current zip: zz_LuaGCTuner-v5.4.zip.

## zz_LuaGCTuner v6.0 (2026-10-04) - current, zz_LuaGCTuner-v6.0.zip (init.lua + meter.lua + SysMemInfo.dll)
- meter.lua: native ink meter (raj font, game panel colors, mappin_icons 'wait' icon, sheared bar + threshold marker, mode, countdown). inkMenuLayer virtual window while a chosen menu is open, inkHUDLayer for gameplay (off by default). Anchor/offset (4K units)/scale/width/background (off / map only / always)/opacity, per-screen toggles; NS options behind "Show advanced options". Simple ImGui countdown box only used when the meter isn't showing it.
- MCM: after rebuilding Native Settings, GetMod('ModConfigurationMenuAPI').reloadMod('cet:LuaGCTuner') (only when that page is open and has no drafts). Hard cap slider is always rangeFloat (MCM matches settings by widget type). MCM hides empty subcategories (use a button to explain).
- Static vs dynamic: NS swaps the unit/cap sliders for a 'Hard cap: dynamic' line; dynamic sliders only shown when dynamic is on. ImGui greys the unused group.
- Menu threshold mode: '% of cap' (menuCollectPct, follows the cap) or 'Exact MB' (stored value no longer clamped; effective value limited to 90% of cap). ImGui: Ctrl+click any slider to type.
- v6.1 (current zip zz_LuaGCTuner-v6.1.zip): per-menu cleanup mode (mode<Kind>: 1 Off / 2 Default wait / 3 Immediately / 4 Custom wait + wait<Kind>) for Pause, Map, Inventory, Journal, Other; old trig* switches migrate (false -> Off). Hard cap and dynamic min/max limited to installed RAM (SysMem_TotalPhysMB; 128 GB without the plugin); readSysMem runs before load().
- Page file explained to Ethan: commit limit = RAM + page file; game committed 35.5 GB with 17.3 GB resident; screenshot showed 28.5 GB RAM free but 1.7 GB commit free. Recommend fixed 32 GB page file.

## zz_LuaGCTuner v6.2-6.4 (2026-10-04) - current zip zz_LuaGCTuner-v6.4.zip
- v6.2: meter placed from the layer's size (TopLeft + computed margin; right/center anchors were ignored inside the letterboxed menu window); meter colors built in M.init (HDRColor does not exist at file load -> v6.1 failed to load).
- v6.3: per-screen meter layout (Inventory, Map, Journal, Pause, Other, Hud): meterOwn<Screen> + meterAnchor/X/Y/Scale<Screen>, Dark-Future-style "Own position (press Apply)" sections; freeze ETA in the countdown; notices say 'Esc menu' / 'map' / 'loading screen'. Ethan's layout: Top right, X 1290, Y 50, scale 0.8.
- v6.4: r6/scripts/LuaGCTunerLHUD/LuaGCTunerLHUD.reds - LHUD bridge (own "Lua GC Tuner meter" section in LHUD's Mod Settings using LHUD's loc keys; LuaGCTunerLHUDSystem.IsVisible()/GetOpacity() recompute LHUD's rule from the same blackboards; everything @if(ModuleExists("LimitedHudCommon"))). Compiled offline with scc both with and without LHUD: 0 errors. Lua polls it at 4 Hz (meterLhud switch).
- Play skill: Documents/claude-skill-tools/cyberpunk-play (cp.ps1 input+screenshot, crop.ps1, find-binding.ps1).
- v6.5 (current zip zz_LuaGCTuner-v6.5.zip): sharp meter text - never SetScale ink text (it rasterizes then scales = blur); multiply font sizes / widths / margins by the scale and round. 'Advanced options' = default look (meter.LOOK: Anchor, X, Y, Scale, Width, Background, BgOpacity, Icon, Percent, Mode, Countdown, Eta) + per-screen 'Override settings' with every LOOK field (meter<Field><Screen>). Screen check throttled to 10 Hz.
- Tuner cost measured (capture 2026-10-03_23-24-50, v4): own logic ~1.7 us/frame (onUpdate 0.5 us + onDraw 1.2 us); the 13.3 s 'exclusive' time is the cleanups themselves (gc_ms). Re-measure v6.5 with RedProfiler (meter + LHUD poll).
- Blur elsewhere: Drone Companion r6/scripts/DroneCompanion/DroneHud.reds uses panel.SetScale (same blur cause); NCA HealthBarVisibility.reds SetScale(0.85,0.9). CET ImGui: config.json font oversample_horizontal 3 / vertical 1.
- v6.6 (current zip zz_LuaGCTuner-v6.6.zip): profiler.lua - Esc-menu ring chart (72 rotated rect segments + legend, top 6 + Other) of per-mod Lua allocations from RedProfiler.MemRows(0, "", 200) ('|' fields, CET rows 'cet:<mod>', Lua KB assumed column 6 - first raw row is printed once to the CET log to verify). Modes: Off / Pause menu only / Sample gameplay after resume (default, profSampleS s, also stops on pause) / Always. Only stops captures it started; SetExportOnStop(false) around its stops. Meter 'Only show above (% of cap)' (meterShowAt, per screen; countdown always shows).

## v6.7 (2026-10-04)
- meter.lua: failed builds no longer retried + logged every frame (15,467 "could not build ... meter.lua:123" lines in ~2 min on 15:22-15:23, HUD layer lookup returned nil). Each distinct error logged once; retry at the 10 Hz screen check; layer lookup falls back to GetLayers() by class name.
- 15:23 crash (police Emperor passenger spawn, ncpd_fleet.archive) is the 2nd identical crash: not a one-off.
- Dynamic cap fell to 672 MB because commit was 58.5/65.5 GB (page file 3.9 GB, game 29.8 GB committed).
- Profiler ring chart removed (Ethan: not scoped as wanted). profiler.lua gone; old prof* keys in settings.json are ignored.
- Anchors: added Bottom center + Center (appended, indices 6/7); X -3000..3000, Y -2000..2000; center anchors 0 = centered; result clamped on screen.
- Per-screen Background = on/off switch (stored 3/1); saved per-screen 2 (Map only) -> on for Map, off elsewhere. Default stays Off / Map only / Always.

## v6.8 (2026-10-04)
- Settings: one always-visible subcategory per screen (/screen<Id>: Pause, Map, Inventory, Journal, Other, Hud) with Clean up here (clean<Id>), Wait (wait<Id>), Show meter, Background opacity (meterBg<Id>, Map 0.85 else 0), Advanced options (meterOwn<Id> + look). Old /menus and /meter<Id> paths removed. Meter section = master + Default look.
- Migration: mode<Id> 1=off, 2=on+pauseWaitS, 3=on+0 s, 4=on+wait<Id>; meterBackground/BgOpacity -> meterBg<Id>.
- Gameplay cleanup (cleanHud, default off): at hudCleanPct % of cap (75), warning, hudWarnS (5 s), skips combat (IsInCombat) / driving (GetMountedVehicle). Pending cleanups feed the meter countdown.
- LHUD link: no longer latched "missing" after 20 failed lookups (5 s, often before a save is loaded); retried every 2 s; logs "Limited HUD link connected" / "not found" once.

## v6.9 (2026-10-04)
- Default wait (pauseWaitS) in main section; per menu "Own wait time" (waitOwn<Id>) + wait<Id>. Migration: v6.8 wait differing from default -> own.
- Meter: green marker at hudCleanPct when gameplay cleanup on; LOOK option EtaAlways ("~X freeze if cleaned now").
- Crash 17:37 (3rd police Emperor passenger crash, during save load at ~[-1510,1473]): police Emperor stack = ncpd_fleet.archive (replaces ent) + NCTO police passengers + Law Enforcement Overhaul + new REDmod "NCPD Prevention Police Enhancement 2.7" (17:31, overrides preventiondata like LEO).

## NCTO-PassengerFix v1.0 (2026-10-04)
Root cause candidate for the 9 police-vehicle occupant crashes today (Emperor + Cortes, incl. NCTO own cortes ent): NCTO.reds:657 auto-assign NCPD list uses Passengers.PolicePassengerBackEntry (capital P; only lowercase exists) -> missing record in randomPassengers; matchRandomPassengersSlots reads past 3-entry lists for 4+ slot vehicles. Patch: TweakXL clone of the misspelled ID + @replaceGlobal capping slots. scc compile of NCTO+patch: clean. autoSetRandomPassengers currently false (user.ini 17:55).
- v1.1: dropped the .reds (@replaceGlobal could not find module function matchRandomPassengersSlots in the full build; offline mini compile passed only because the @if guard skipped it). Typo fix (yaml) only.
- v1.2: + Passengers.AldelcaldosDriverEntry (Factions Evolved typo, TweakXL warns non-existent).
- Use Your Fridge Food&Drinks Filter requires More Inventory Filters and is incompatible with More Weapon Filters (Nexus 27740 description) - both filter mods installed -> stash grid flicker.

## NCTO-PassengerFix v1.3 (2026-10-04 18:55)
- Crash 18:48: same +0x33F1BC / SimpleOccupantSlotSpawner signature, this time on Arch V4 Fyrn bike (BDF_DRe_Arch_V4, ep1\vehicles\sportbike\v_sportbike2_arch_v4_fyrn.ent). Factions Evolved aldecaldos__modded_arch_fyrn_gray/vigil_gray use missing Passengers.AldelcaldosDriverEntry -> confirms "missing passenger entry record => load crash" mechanism.
- v1.2 cloned Passengers.AldecaldosDriverEntry, which no installed mod defines; v1.3 clones NCTO's Passengers.AdelcaldosDriverEntry (Aldecados.yaml) instead. v1.2 superseded, never install it.
- Audit tool: id-check-commands.txt (15 CET lines, 5179 Passengers/Character/Vehicle IDs from reds+lua across 64 mods); paste each into the CET console, grep scripting.log for "IDCHK MISSING".

## SONC-SpawnGuard v1.0 (2026-10-04 19:06)
- Crash 18:54:31: PhysX3_x64+0xD8959 invalid read, redDispatcher thread in ScriptableSystems/Tick running StreetsOfNightCity_System.OnAmbientSpawnCheckRequest -> FindPedestrianSpawnPoint -> IsDefinitelyIndoor -> SyncRaycastByCollisionGroup, while another thread ran Physics/UpdateInBucket; ~7 s after save load. Same signature reported on SONC posts tab (Luments0, City Center roundabout while driving, persists with conflicts/patrols at 0).
- Patch = full copy of SONC 15.7.5 r6/scripts/STREETS OF NIGHT CITY/SONC_System.reds with inline guard (ambient, immersive, spawn-queue handlers reschedule while: no player, <30 s after player appears, or mounted vehicle > 15 m/s). Original kept in SONC-SpawnGuard-source/original-15.7.5. Must be redone for each SONC update. Vortex: file conflict, patch loads after SONC.
- scc quirk: @wrapMethod / @addMethod targeting StreetsOfNightCity_System fail offline ("no method with this name exists" / constant pool error) even for public methods; global funcs referencing the class work. Hence the inline copy.
- Offline compile recipe that works: copy r6/scripts + every red4ext/plugins/**/ dir containing .reds (ArchiveXL/Scripts, Codeware/Scripts, NewGamePlus/redscript (parent only), PhotoModeEx/Scripts, TweakXL/Scripts, XUtils/scripts, in_world_navigation, mod_settings) + fresh r6/cache/final.redscripts -> baseline 0 errors.
- SONC bug tracker: Crippled/Sandevistan bug already fixed in 15.7.5 (player gated by experimental setting + cleanup on load). Open/unfixed reports: combat aggro persisting across map, mid-air spawns, retaliation squads spawning close.

## TrafficCrewFix v1.0 + VSF cleanup (2026-10-04 19:45)
- Symptom: hostile non-police NPCs exiting an NCPD Behemoth. Cause: VSF had "enable all modded cars" (1979 on), incl. 138 LEO heat records, 40 FE GR_ reinforcement records, ~178 *_prevention records, quest/scene/savable/hackable records; and dealer copies (NCPD Fleet vcd_*) inherit civilian crews (vcd_militech_behemoth_police = WorkerSpecialist).
- CET dump (vsf-police-passenger-check.txt -> scripting.log VSFPAX) of 626 police/corp-themed VSF cars saved in TrafficCrewFix-source/vsfpax-2026-10-04.json. tools/traffic_crews.py builds r6/tweaks/zz_TrafficCrewFix/TrafficCrewFix.yaml: 80 faction-named cars with civilian crews get faction crews (only passenger entries known to exist; bikes only where a biker entry exists; 'militech_hellhound/behemoth' treated as manufacturer).
- vsf-disable-list.json: 753 entries (name rules: leo_, GR_, RS_, max_tac_av, cs_savable_, hackable_, *_prevention, *_heat_N, quest/mws/sts/heist, nonexistent records). Apply with tools/vsf_disable.py (game closed; backs up user_settings.json).
- NCTO auto-assign stays OFF: besides the PolicePassengerBackEntry typo it indexes desiredPassengers[i] past 3 entries for 4+ seat vehicles, and its Aldecaldos list uses Passengers.AldecaldosDriverEntry (doesn't exist; NCTO's own yaml spells it Adelcaldos).
- Pending: vsf-gang-passenger-check.txt (286 gang-named VSF cars) -> extend crews in v1.1.

## TrafficCrewFix v1.1 (2026-10-04 19:50)
- Gang check ran (vsf-gang-passenger-check.txt, 288 rows merged into TrafficCrewFix-source/vsfpax-2026-10-04.json). v1.1 = 137 crew fixes (adds Tyger, Valentinos, Scavengers, 6th Street, Maelstrom, Wraith, Voodoo, Mox, Barghest). Mox/Animals bikes stay civilian (no biker entry). Generic "nomad" cars stay civilian.
- vsf-disable-list.json now 762 (9 new: nonexistent *_edge_* / Shion_MZ*/GalenaNomad records). VSF already applied for the first 753 at 19:41 (backup user_settings.backup-20261004-194135.json); rerun tools/vsf_disable.py vsf-disable-list.json with the game closed to apply the 9 new ones.

# >>> NEXT SESSION: START HERE (written 2026-10-04 ~19:50) <<<
Install / apply (Ethan, via Vortex):
1. NCTO-PassengerFix-v1.3.zip - already deployed. Never install v1.2.
2. TrafficCrewFix-v1.1.zip - install (replaces nothing; new r6/tweaks/zz_TrafficCrewFix). Check TweakXL log after launch for errors mentioning zz_TrafficCrewFix.
3. Game closed: python tools/vsf_disable.py vsf-disable-list.json (9 remaining entries).
4. SONC: Ethan leaning to disable it (decision pending; he found a SONC guide he wants to look at). If kept: install SONC-SpawnGuard-v1.0.zip (replaces SONC_System.reds; Vortex conflict -> patch after SONC). If removed: quiet spot, manual save, disable in Vortex, do NOT install SpawnGuard.
5. Page file: recommended C: 4096-8192 MB, D: 32768 fixed (C: has ~27 GB free; Steam library ~920 GB on C:). hiberfil.sys 24.6 GB (powercfg /h off if no hibernate). Ethan to do this himself (system setting).
Open checks:
- memlog: tools/memlog.ps1 (run in background while playing; writes memlog-session.csv) + memchk-cet.txt CET line; compare SysMemInfo values vs Task Manager. Not yet captured with the game running.
- id-check-commands.txt (15 CET lines, script-literal TweakDB IDs) never run.
- 18 missing spawn vehicleRecords in LEO/Factions Evolved prevention tables (see earlier section) - candidate for a yaml redirect patch.
- Stash flicker: More Weapon Filters vs More Inventory Filters - Ethan to disable More Weapon Filters, retest.
- zz_LuaGCTuner v6.9 still untested in game (LHUD link log line, gameplay cleanup, green marker).
- NCTO "Auto Assign Passengers" must stay OFF (typo + >3-seat index bug + missing Aldecaldos IDs).

## FAC-TimeskipPosition v1.0 (2026-10-04 20:00)
- Flesh & Chrome sleep-menu (TimeskipGameController) stamina/energy bars overlapped Dark Future's. Patch = replacement copies of FleshAndChrome_Config/_DVRCF/_TimeskipUI.reds: two DVRCF sliders under Rest/Sleep after "Show bars on timeskip": horizontal offset (-1500..1500, 0 = centred) and vertical offset (-200..1600, 0 = FAC original -100 px). Originals in FAC-TimeskipPosition-source/original. scc full-set compile: 0 errors. Note: redscript rejects negative literal defaults on fields (INVALID_CONSTANT), hence the relative Y.
- Confirmed from LimitedHudNeedsBars source notes: "@wrapMethod cannot target a class declared in redscript" - explains the SONC wrap failure. Patching another mod's classes = replace its files (or blackboard/widget-name tricks).

## NEXT: Lua GC Tuner LHUD still not working (Ethan, 2026-10-04)
- scripting.log has NEITHER "Limited HUD link connected" NOR "Limited HUD link not found" from v6.9 in any of 5 launches today, so the LHUD probe in init.lua never runs or errors silently -> start by tracing why (pcall swallowing? only runs when meter screen = Hud?).
- Reference that works for Ethan: LimitedHudNeedsBars (Nexus 33337, r6/scripts/LimitedHudNeedsBars) - gate is hide-only, reads LHUD blackboard fields IsGlobalFlagToggled_LHUD / IsMounted_LHUD with @if guards, and applies opacity/visibility to a widget property the owning mod never writes. Ask Ethan what exactly fails (meter never hides? never shows? settings page missing?).

## Lua GC Tuner v6.10 / v6.11 (2026-10-04)
- v6.10: LHUD bridge "Show with scanner".
- v6.11: Esc menu split into "Esc menu (Resume list)" (default: top center X -1340 Y 360, scale 1.0, width 460 = just above Resume, estimated from a screenshot) and "Mod Configuration Menu & other Esc pages" (default = Ethan's old Esc meter: top center X -360 Y 100, scale 1.25, width 610). Existing settings migrate (old Esc values move to MCM). Page detection: r6/scripts/LuaGCTunerLHUD/LuaGCTunerMenu.reds (MenuScenario_BaseMenu m_currMenuName|m_currSubMenuName); overlay shows "Current menu: pause (page: ...)". Follow-LHUD switch removed (always on when the bridge exists). Overlay gameplay section shows LHUD link + active conditions. Offline compile clean. Untested in game.
- Fullscreen Browser (Nexus 34417) installed by Ethan, works. Page file: D: 32768 fixed, C: system managed (set 2026-10-04, reboot pending).

## LHUD-ScannerOptions v1.0 + Lua GC Tuner v6.12 (2026-10-04)
- LHUD-ScannerOptions-v1.0.zip: replaces LHUD 2.22.4 config.reds + modules/{actionButtons,crouchIndicator,weaponRoster,hints,playerHealthbar,playerStamina}.reds, adding "Show with scanner" (13 visibility rules). Generated by tools/lhud_scanner_patch.py from the installed LHUD (originals in LHUD-ScannerOptions-source/original). Vortex: must win the conflict over Limited HUD. Re-run the tool after any LHUD update.
- Lua GC Tuner v6.12: MCM meter only when MCM is drawn (SettingsMainGameController:McmUiIsActive()); vanilla settings/save/load pages hide the meter.
- Open: Dark Future needs bars vs scanner. LimitedHudNeedsBars has ShowWithScanner=true in user.ini and DF has no scanner code; waiting on Ethan's description of what happens.

- Lua GC Tuner v6.13: LHUD bridge reads LHUD's published flags (AllBlackboardDefinitions.lhud_*) instead of re-deriving from blackboards; v6.10-6.12 showed the HUD meter while LHUD hid everything.

- 2026-10-04: Ethan removed Dark Future (clashed with Flesh & Chrome). Dark Future questions are closed. FAC-TimeskipPosition only existed to move FAC sleep-menu bars off Dark Future's, so it is optional now. LimitedHudNeedsBars still gates Flushing Etiquette / SynthDose.

## Load-time phantom weapon (2026-10-05)
- Every load: weapon roster (SMG, 00/0000) shows and crowds flee; draw+holster clears it. CET probe after load: WeaponRight empty, GetActiveWeapon none, HasWeaponEquipped false, UpperBody 0. LHUD PostLaunchCall (1 s after spawn) reads HasAnyWeaponEquipped_LHUD (WeaponRight slot), so a weapon is briefly in hand at load and is removed without a holster.
- Ruled out: Always First Equip (tested disabled), StreetSense clothing fear (fearScore 0), 2BT (inventory puppet only), Visual Holsters (clothing swaps), Cutscene Weapon Swapper.
- LHUD-LoadResync-v1.0.zip: re-queues the LHUDEventType.Weapon state 3 s and 8 s after player attach (HUD fix). WeaponSlotProbe-v1.0.zip: temporary CET logger (20 s after load) to find the brief draw.
- Backpack hover flicker: backpack only; not Inventory Instant Preview (tested), not More Inventory Filters (off). Next: bisect More Weapon Filters, Flesh & Chrome InventoryUI, Backpack Search, MarkToSell, Equipment Bonus Stat.
