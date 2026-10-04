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
