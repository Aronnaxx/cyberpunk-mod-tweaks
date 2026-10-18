# Cyberpunk 2077 mod patches (Ethan's setup)

Ethan's own patches, probes and tools for his heavily modded Cyberpunk 2077, plus backups. History of every
investigation and patch version: [HANDOFF-cyberpunk-modding.md](HANDOFF-cyberpunk-modding.md). It's append-only;
add a dated `## <Patch> vX.Y (YYYY-MM-DD)` section for each change. Older sections may be outdated; this file wins.

## Setup
- Patch 2.31 (game 3.0.80), Steam. Fem V. RTX 5090, Ryzen 7 9800X3D, 64 GB RAM, 3440x1440 @ 240 Hz, HDR, path tracing, DLSS 4.5 FG x2.
- Game: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`
- Vortex: `C:\Program Files\Black Tree Gaming Ltd\Vortex\Vortex.exe`, staging `%APPDATA%\Vortex\cyberpunk2077\mods\<mod>`, downloads `%APPDATA%\Vortex\downloads\cyberpunk2077`. Auto-deploy is ON. Mods come from collection NightCity2026 plus Ethan's additions.
- Mod Settings UI: Mod Configuration Menu over Native Settings (changes need MCM's APPLY). DigitalVixen mods (F&C, FACC, Street Sense, DV Core) save settings in `r6\storages\RedscriptConfigFramework\<Mod>.json`.
- Logs: `r6\logs\redscript_rCURRENT.log` (script compile), CET `bin\x64\plugins\cyber_engine_tweaks\scripting.log` + per-mod logs, ACR crash reports `bin\x64\plugins\AdvancedCrashReporter\reports\`, `red4ext\logs`, TweakXL/ArchiveXL logs.

## Ground rules
- Downloads, installs and anything system-level need Ethan's OK. He changes system settings (Device Manager, page file) himself.
- Never store or repeat API keys/tokens seen in logs (Nexus key, RedHttpClient bearer token).
- **Don't interrupt Ethan's desktop.** He plays other games while I work. Run compile checks only through `tools/scc_check.ps1` (hidden; it closes scc's modal error box), via the PowerShell tool. Before any GUI input (`tools/desk.ps1`, `tools/vortex_find.ps1`) make sure no game process is running at all (`Get-Process`); a minimized game can grab focus back mid-sequence. If one is, use a non-GUI route or leave the GUI step to him.
- Drone Companion is his #1 must-keep mod. NCTO "Auto Assign Passengers" stays OFF. Never install NCTO-PassengerFix v1.2.

## Vortex: how to deploy (every patch)
- **Install a patch zip:** `Vortex.exe --install-archive <full path of the zip in this folder>` (no prompts, auto-deploys). Ethan can instead drag the zip onto the Mods tab. NEVER run `--install-archive` on a file inside Vortex's downloads folder: Vortex deletes it. Nexus mods: `nxm://cyberpunk2077/mods/<modId>/files/<fileId>`.
- **Remove / disable a mod:** GUI only (Mods tab > Mod Name filter > select > Remove or toggle, then Deploy). If a game is running, ask Ethan to do it. To neutralize a deployed mod without the GUI, overwrite its deployed files in place with a stub (see next point).
- **Change a deployed file:** deployed files are hardlinks into staging. Write into the existing file (`open(p,'r+b')` + truncate, or read-modify-write), which updates staging too. `sed -i`, delete+recreate or PowerShell Set-Content replace the file, break the link, and Vortex reverts it.
- **Overrides of another mod's files** must win the Vortex conflict (patch loads after the original). Check the conflict after installing.
- **External Changes dialog** after a purge/cleanup: ALWAYS "Revert all changes" or Cancel, never "Save" (lost 530 staging folders on 2026-10-05). "File exists - replace?" from a queued install: Cancel. "Install options": Replace + Continue.
- After deploying: check the files under the game folder, run `tools/scc_check.ps1` for redscript, and tell Ethan what to look for in game.
- Clean-reinstall runbook: [RUNBOOK-clean-reinstall.md](RUNBOOK-clean-reinstall.md).

## Patch conventions
- Layout: `<Mod>-<Fix>-source/` (game-relative tree, e.g. `r6/scripts/<Folder>/...`, plus `original/` copies of any file replaced or copied) and `<Mod>-<Fix>-vX.Y.zip` at the repo root. Bump the version for every shipped change; delete superseded zips you made.
- Build zips with Python `zipfile` (forward-slash paths, no folder entries). PowerShell `Compress-Archive` writes backslash paths.
- Patches that copy another mod's file must be redone when that mod updates. Say so in HANDOFF, and keep a `make_patched.py`/tool when the copy is mechanical.
- Write `.reds` files as UTF-8 without BOM: PS 5.1 `Set-Content -Encoding utf8` adds a BOM and redscript fails at 1:1. Resource paths in redscript are `r"base\\gameplay\\..."` (doubled backslashes); quoted shell heredocs keep them, but check after any scripted rewrite.

## Redscript rules learned (this build)
- Test at the real path: `tools/scc_check.ps1 -Override <source folder>` puts the folder at `r6\scripts\<name>`, replacing a deployed copy. `-Extra` compiles outside r6 and can pass while the game fails. Baseline: errors=0, ~31 warnings.
- Annotate game classes only. `@wrapMethod`/`@addMethod`/`@replaceMethod` on a class declared by another mod's scripts fail (SONC's StreetsOfNightCity_System, EquipmentEx's WardrobeScreenController). Patch that mod's file instead, or hook a game class it uses.
- A method another mod added to a game class (`@addMethod`) can be wrapped only if that mod's folder compiles before yours (alphabetical). EquipmentEx's ShowWardrobeScreen wraps fine from "FACC..."; Street Sense's OnSSBtnToggleEvent does not.
- To react to another mod's UI event, add your own `cb func` taking that event type rather than wrapping its handler.
- `@if(ModuleExists("X"))` guards optional dependencies. Qualified names (`@wrapMethod(Mod.Class)`) are invalid. No negative literal defaults on fields (INVALID_CONSTANT).
- Ink: fullscreen UI uses 4K (3840x2160) units. Never SetScale text widgets (blurry); scale sizes/fonts instead. Writing to a widget inside a menu's virtual window re-runs that window's layout (caused the 10-05 tooltip flicker).
- Lua (CET) can't be compiled offline; stub-test with lupa when it matters. CET's sandbox has `collectgarbage` but not `jit`.

## Tools (`tools/`)
- `scc_check.ps1` offline redscript compile of the deployed set (+ `-Override`/`-Extra`).
- `desk.ps1` (focus/click/type/screenshot; `-NoFocus -Shot` to just look), `vortex_find.ps1` (Mods tab name filter via OCR), `ocr_region.ps1`.
- `vsf_disable.py` (Vehicle Spawn Fix list, game closed), `traffic_crews.py`, `lhud_scanner_patch.py`, `leveldb_dump.py` (Vortex state, read-only), `settings_backup.py` / `restore_settings.py`, `snapshot_backup.ps1` / `snapshot_restore.ps1`, `memlog.ps1`, `colcheck*.py` (collection overlap check).
- Skills: cyberpunk-mod-audit, cyberpunk-performance-tuning, nexus-mods-via-chrome.
