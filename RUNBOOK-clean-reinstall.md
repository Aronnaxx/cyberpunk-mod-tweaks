# Clean reinstall runbook (2026-10-09)

Backup already taken: `clean-install-backup-2026-10-09/` (4180 unmanaged settings/db files, 16 mod files edited in place
incl. MySettings' user.ini, key bindings, UserSettings, saves, deployment manifest). Made by `tools/settings_backup.py`.
Saves are never touched by the bat (Saved Games folder).

## A. Vortex state backup (Vortex + game CLOSED)
Copy `%APPDATA%\Vortex\state.v2` to `clean-install-backup-2026-10-09\vortex-state.v2` (locked while Vortex runs).
Do NOT delete `%APPDATA%\Vortex\downloads` (33 GB of archives = offline reinstall source).

## B. Wipe
1. Vortex: Deploy tab > **Purge**. If an "External changes" dialog appears: **Revert all changes / Cancel. NEVER "Save"**
   (Save deletes the source file in staging; this destroyed 530 mods on 10-05).
2. Run the Cyberpunk folder's `cyberpunk2077_disable_all_mods.bat` (Enter to confirm). It moves every mod file to
   `_MOD_REMOVER_BACKUPS\<timestamp>`. The "filename syntax" error about engine\config\base is harmless.
3. Optional: Steam > Cyberpunk 2077 > Properties > Installed Files > Verify integrity.
4. Launch the game once from Steam (vanilla), reach the main menu, quit. (Regenerates r6\cache, UserSettings.)

## C. Reinstall
1. Vortex Mods tab: remove all mods (archives are kept; untick "remove archive").
2. Install collection jhn3im revision 1 (Premium = automatic). Archives already in downloads are reused.
3. `powershell -File tools\install_local_patches.ps1` (add `-IncludeOptional` for LHUD-LoadResync, NativeInteractions-DistanceGate, marmurbank-InputGuard).
   If Vortex asks "File exists - replace?" for an older copy: Cancel.
4. Vortex: set the 27 left-out mods (mods-not-in-collection.json) by hand if wanted. Check conflict rules: all local patches must load AFTER what they patch. Deploy.

## D. Restore settings (game closed)
```
python tools\restore_settings.py --dry-run
python tools\restore_settings.py
```
Pass 1 copies only files that don't exist (mod databases, CET settings, r6\storages...). Pass 2 writes the edited
mod files (MySettings user.ini etc.) in place. Key bindings: copy
`clean-install-backup-2026-10-09\game-edited-mod-files\r6\cache\inputUserMappings.xml` to `r6\cache\` if bindings are lost.
UserSettings.json (graphics): copy from `clean-install-backup-2026-10-09\appdata-game-settings\` if the game reset it.
Then launch, check Mod Settings / CET, and load a save.

## Lessons from the 2026-10-09 run
- NEVER pass `Vortex.exe --install-archive` a file that is already inside `%APPDATA%\Vortex\downloads\cyberpunk2077`.
  Vortex "imports" it onto itself, deletes the original, then fails ("Import Failed ... ENOENT"). It lost 12 archives (permanently, not in the
  Recycle Bin); the staged mods were fine and the archives were re-downloaded via nxm://cyberpunk2077/mods/<modId>/files/<fileId>.
  Use --install-archive only for zips OUTSIDE downloads (our patch zips in this repo), or use nxm links.
- A "File exists - replace?" dialog for a file in downloads: Cancel. "Install options: Replace the existing mod": Replace + Continue.
- Purge = Vortex GUI only. The bat needs `.\cyberpunk2077_disable_all_mods.bat` run from the game folder in PowerShell; follow it with Steam Verify.
- Collection installs leave the user's own-disabled mods enabled when re-fetched: re-disable them.
