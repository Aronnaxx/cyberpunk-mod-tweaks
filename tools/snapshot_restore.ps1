# Roll the game back to a snapshot made by snapshot_backup.ps1.
# Mirrors each part back, so files added since the snapshot (e.g. a new mod) are deleted.
# Usage: powershell -File snapshot_restore.ps1 -Name pre-VR-2026-10-06 [-WhatIf]
param([Parameter(Mandatory)][string]$Name, [string]$Root = 'C:\CP2077-Backups', [switch]$WhatIf)

$ErrorActionPreference = 'Stop'
if (Get-Process Vortex, Cyberpunk2077 -EA SilentlyContinue) { throw 'Close Vortex and Cyberpunk 2077 first.' }

$game = 'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
$src  = Join-Path $Root $Name
if (-not (Test-Path "$src\README.txt")) { throw "No snapshot at $src" }

$parts = [ordered]@{
    'game'          = $game
    'appdata'       = "$env:LOCALAPPDATA\CD Projekt Red\Cyberpunk 2077"
    'vortex-state'  = "$env:APPDATA\Vortex\state.v2"
    'vortex-staging'= "$env:APPDATA\Vortex\cyberpunk2077"
    # Saves are copied back without /MIR so saves made after the snapshot are kept.
    'saves'         = "$env:USERPROFILE\Saved Games\CD Projekt Red\Cyberpunk 2077"
}
foreach ($k in $parts.Keys) {
    $dst  = $parts[$k]
    $rc = @((Join-Path $src $k), $dst, '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NP', '/NDL', "/LOG:$src\restore-$k.log")
    $rc += if ($k -eq 'saves') { '/E' } else { '/MIR' }
    if ($k -eq 'game') { $rc += @('/XD', "$game\archive\pc\content", "$game\archive\pc\ep1") }
    if ($WhatIf) { $rc += '/L' }
    Write-Host "== $k -> $dst"
    & robocopy @rc | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $k (exit $LASTEXITCODE), see restore-$k.log" }
}
Write-Host 'Restored. Open Vortex and let it reconcile; then Steam > Verify integrity if the vanilla archives changed (compare vanilla-archives.csv).'
