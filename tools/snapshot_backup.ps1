# Full rollback snapshot of the modded Cyberpunk 2077 setup.
# Usage: powershell -File snapshot_backup.ps1 -Name pre-VR-2026-10-06
# Close Vortex and the game first (Vortex's LevelDB state must not be open).
param([Parameter(Mandatory)][string]$Name, [string]$Root = 'C:\CP2077-Backups')

$ErrorActionPreference = 'Stop'
if (Get-Process Vortex, Cyberpunk2077 -EA SilentlyContinue) { throw 'Close Vortex and Cyberpunk 2077 first.' }

$game  = 'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
$dest  = Join-Path $Root $Name
$parts = [ordered]@{
    # Everything in the game folder except the vanilla base archives (Steam "Verify" restores those).
    'game'          = $game
    'saves'         = "$env:USERPROFILE\Saved Games\CD Projekt Red\Cyberpunk 2077"
    'appdata'       = "$env:LOCALAPPDATA\CD Projekt Red\Cyberpunk 2077"   # UserSettings.json
    'vortex-state'  = "$env:APPDATA\Vortex\state.v2"
    'vortex-staging'= "$env:APPDATA\Vortex\cyberpunk2077"
}
New-Item -ItemType Directory -Force $dest | Out-Null

foreach ($k in $parts.Keys) {
    $src = $parts[$k]
    $rc = @($src, (Join-Path $dest $k), '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NP', '/NFL', '/NDL', "/LOG:$dest\robocopy-$k.log")
    if ($k -eq 'game') { $rc += @('/XD', "$game\archive\pc\content", "$game\archive\pc\ep1") }
    Write-Host "== $k <- $src"
    & robocopy @rc | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $k (exit $LASTEXITCODE), see robocopy-$k.log" }
}

# Hash list of the vanilla archives we skipped, so a restore can confirm they are untouched.
Get-ChildItem "$game\archive\pc\content", "$game\archive\pc\ep1" -File |
    Select-Object FullName, Length, LastWriteTime | Export-Csv "$dest\vanilla-archives.csv" -NoTypeInformation

@"
Snapshot $Name taken $(Get-Date -Format s)
game          = $game (minus archive\pc\content, archive\pc\ep1)
saves, appdata (UserSettings.json), Vortex state.v2 and cyberpunk2077 staging folder
Restore with tools\snapshot_restore.ps1 -Name $Name
"@ | Set-Content "$dest\README.txt" -Encoding utf8

$gb = (Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Host ("Done: {0} ({1:N1} GB)" -f $dest, $gb)
