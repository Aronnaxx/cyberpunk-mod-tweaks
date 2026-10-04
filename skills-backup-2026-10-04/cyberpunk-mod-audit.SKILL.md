---
name: "cyberpunk-mod-audit"
description: "Audit Ethan's Vortex-managed Cyberpunk 2077 mods: find duplicates, conflicts, overwrites, leftovers, errors, armor/itemfacts gaps, and produce a keep/drop report."
---

# Cyberpunk 2077 mod audit (Vortex)

Use when Ethan asks what a group of mods does, whether mods overlap or conflict, why something broke after an install, which mods are redundant, or whether gear "counts as armor".

## Environment (Ethan's PC "blackbox", reached via device_bash)
- Game: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077` → `$HOME/mnt/Cyberpunk 2077`
- Vortex staging: `%APPDATA%\Vortex\cyberpunk2077\mods` → `$HOME/mnt/mods` (one folder per mod, name contains Nexus id + version)
- Vortex AppData: `$HOME/mnt/Vortex` (state DB at `state.v2`, LevelDB)
- Backups / custom files: `C:\Users\wyant\Documents\CET-Cleans` → `$HOME/mnt/CET-Cleans`
- Profile: "NCR Core 2.31a" (id `T9yifKpt-`), game patch 2.31. Ethan plays **Fem V** (check `isFemale=true` in logs if unsure).
- Ethan wants everything installed/removed through Vortex. Don't install mods by hand; tell him what to toggle.
- If a folder isn't connected, request it once with device_request_folder_access.

## Ground truth: what is actually deployed
`vortex.deployment.json` in the game root lists every deployed file (`relPath`, `source` = staging folder). Always re-read it; never trust earlier data (Ethan changes things between messages). Example:
```python
import json
d=json.load(open('vortex.deployment.json'))
src={f['source'] for f in d['files']}
# which mod owns a path
[f['source'] for f in d['files'] if 'backstorymanager' in f['relPath'].lower()]
```
- A staged mod that is absent from `source` = disabled/not deployed.
- Two mods shipping the same relPath = file conflict; only the `source` listed wins. Diff the loser's copy against the winner's (`diff <(sed 's/[[:space:]]*$//' A) <(...)`) to see what is lost. Check versions: a patch built on an older base silently downgrades it (e.g. TraumaTeamCorpo replacing Deep Scan's BackstoryManager.reds).
- Vortex state (enabled flags, install times) is LevelDB: .log/MANIFEST are locked while Vortex runs; parse the `.ldb` tables only (copy to $HOME, snappy via `pip install --user cramjam`). Keys look like `persistent###profiles###T9yifKpt-###modState###<modFolder>###enabled`.

## What to check
1. **Inventory a group**: list staging folders matching keywords; per mod print file types and non-asset files (reds, lua, yaml, xl, json). Skip .archive/.wav/etc.
2. **Purpose**: read `r6/storages/RedscriptConfigFramework/*.docs.txt` (full Nexus description shipped with DigitalVixen-style mods), ModSettings `displayName/description` runtimeProperties in .reds, yaml comments (`# ... Game.AddToInventory(...)`), and the Nexus page (see nexus-mods-via-chrome skill) for summary + requirements.
3. **Overlaps**: same feature from two mods (death/rescue systems, two vehicle variants, multiple outfit sets, two customizers, odometers, settings menus). Check each mod's documented compatibility list.
4. **Requirements**: Nexus requirements vs deployed set; a removed dependency (or a removed mod another one requires, like Second Heart Combat Fix for Mai Hasegawa) shows up as a Vortex warning.
5. **Errors**: CET logs `bin/x64/plugins/cyber_engine_tweaks/mods/<mod>/<mod>.log`, `scripting.log`; redscript `r6/logs/redscript_rCURRENT.log` (WARN/ERROR); ArchiveXL/TweakXL logs in `red4ext/plugins/*/`; `r6/logs/mods/*.log`. Count errors per day with timestamps before calling something "broken" (old errors may be fixed).
6. **Leftovers**: CET folders without init.lua, r6/scripts folders with only `__folder_managed_by_vortex`. Harmless; only list them.

## Armor in this setup
- Vanilla 2.x clothing has no armor. Flesh & Chrome is stamina/energy (its Carry Overhaul reads carry/holster only).
- **Chrome Plating** makes clothing armor work. Pool values come from the **DigitalVixen Core item database**: shipped `r6/storages/DigitalVixenCore/itemfacts.json`, plus user overrides `itemfacts.user.json` (same folder). Patterns match by case-insensitive substring on the record path, longest wins. Row format: `"Items.prefix_": {"armor": "light|medium|heavy", "armorValue": N, "carry": N}`. Keep the `$comment` key.
- Reference values (Zenitex / Military Combat Armor): armored vest heavy 250, assault vest medium 100, harness medium 80, combat helmet heavy 175, shoulder/thigh pad medium 40, knee/elbow light 25.
- Before adding rows, check the item's yaml for `equipPrereqs`/`visibilityPrereqs` gender locks (TraumaV armor_01-03 are Male-only).
- After writing the user file, copy it to `CET-Cleans/DigitalVixenCore-itemfacts/`.

## Output
- Short chat summary: concrete actions (keep / drop / choose one / fix), each with the reason and evidence.
- For a multi-mod review, publish an HTML artifact (load artifact-design first): action cards on top, then a filterable per-mod register with name + Nexus link, what it does, playthrough impact (1-5), verdict, notes, error counts. Re-publish the same file when rechecking and mark removed mods.
- Say plainly when earlier advice was wrong (e.g. a fix that is a dependency) and correct the report.