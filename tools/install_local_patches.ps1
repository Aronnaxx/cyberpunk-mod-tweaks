# Install our local patch zips into Vortex one at a time (Vortex must be running, Cyberpunk profile active).
# Order matters only for conflicts: MySettings and the patches must win over the Nexus mods they override,
# so install them AFTER the collection, then check Vortex's conflict rules.
# Usage: powershell -File install_local_patches.ps1 [-IncludeOptional]
param([switch]$IncludeOptional)
$repo   = 'C:\Users\wyant\Documents\cyberpunk-mod-patches'
$vortex = 'C:\Program Files\Black Tree Gaming Ltd\Vortex\Vortex.exe'
$zips = @(
  'MySettings-v1.0','zz_LuaGCTuner-v6.14','LHUD-ScannerOptions-v1.0','LoadCalm-v1.0','PedBumpCalm-v1.0',
  'DPR-CombatCrashFix-v1.0','0-Engine-StateThrottle-v1.0','DedkaAutoShop-DrawFix-v1.0',
  'DroneCompanion-LootThrottle-v1.0','FAC-TimeskipPosition-v1.0','MansionDLC-Fixes-v1.3',
  'NCTO-PassengerFix-v1.3','SmasherEncounters_Patched-v2.0','TrafficCrewFix-v1.1',
  'smartWindow-Throttle-v1.0','yaibaPenthouse-DistanceGate-v1.0','MapFilterFix-v1.0')
if ($IncludeOptional) { $zips += 'LHUD-LoadResync-v1.0','NativeInteractions-DistanceGate-v1.0','marmurbank-InputGuard-v1.0' }
foreach ($z in $zips) {
  $p = Join-Path $repo "$z.zip"
  if (-not (Test-Path $p)) { Write-Warning "missing $p"; continue }
  Write-Host "installing $z"
  & $vortex --install-archive $p
  Start-Sleep -Seconds 8   # let Vortex finish before queueing the next one
}
