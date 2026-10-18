# Automated Cyberpunk 2077 check for the two open bugs, step by step:
#   -Step launch   start the game (-modded, like Vortex) and wait for the main menu (OCR finds CONTINUE)
#   -Step load     click CONTINUE, wait for WeaponSlotProbe's "player attached" + its 20 s window, report weapon events,
#                  screenshot the bottom-right HUD
#   -Step backpack open the inventory, open BACKPACK, park the cursor on an item for -HoverS seconds without moving,
#                  report MenuInputProbe hover IN/OUT counts (flicker = repeated IN/OUT on one item) + 3 screenshots
#   -Step quit     close the game
#   -Step all      launch, load, backpack, quit; prints one summary line
# Needs the WeaponSlotProbe and MenuInputProbe CET mods deployed. Screenshots go to %TEMP%\claude\gt_*.png.
param(
  [ValidateSet('launch', 'load', 'backpack', 'quit', 'all')] [string]$Step = 'all',
  [int]$HoverS = 10,
  [int]$ItemX = -1, [int]$ItemY = -1   # absolute screen point of a backpack item; default = calibrated value below
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$desk = "$tools\desk.ps1"
$ocr = "$tools\ocr_region.ps1"
$game = 'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
$cetMods = "$game\bin\x64\plugins\cyber_engine_tweaks\mods"
$wsLog = "$cetMods\WeaponSlotProbe\WeaponSlotProbe.log"
$miLog = "$cetMods\MenuInputProbe\MenuInputProbe.log"
# Calibrated on Ethan's 3440x1440 screen (first backpack item tile). Updated after the first live run.
$DefaultItem = @(560, 520)

function Shot($name) { & $desk -Proc Cyberpunk2077 -NoFocus -WaitMs 50 -Shot -ShotName "gt_$name" | Out-Null; "$env:TEMP\claude\gt_$name.png" }
function Key($k, $hold = 80) { & $desk -Proc Cyberpunk2077 -Key $k -HoldMs $hold -WaitMs 300 | Out-Null }
function FindWord($pattern) {
  $hits = & $ocr -Full -Words | Where-Object { ($_ -split "`t")[0] -match $pattern }
  if ($hits) { $p = ($hits | Select-Object -First 1) -split "`t"; return @([int]$p[1], [int]$p[2]) }
  return $null
}
function WaitWord($pattern, $timeoutS) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $timeoutS) {
    & $desk -Proc Cyberpunk2077 -WaitMs 50 | Out-Null   # the game can open behind other windows: bring it to the front
    $pt = FindWord $pattern; if ($pt) { return $pt }; Start-Sleep 2
  }
  return $null
}
function LinesSince($path, $count) { if (Test-Path $path) { @(Get-Content $path | Select-Object -Skip $count) } else { @() } }
function LineCount($path) { if (Test-Path $path) { @(Get-Content $path).Count } else { 0 } }

function Launch {
  if (-not (Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue)) {
    Start-Process "$game\bin\x64\Cyberpunk2077.exe" -ArgumentList '-modded' -WorkingDirectory "$game\bin\x64"
  }
  $pt = WaitWord '^CON[A-Z]{3,6}E$' 300   # OCR reads the game font's CONTINUE loosely (e.g. CONFINIJE)
  if (-not $pt) { Shot 'launch_fail' | Out-Null; throw "main menu not found within 300 s" }
  "menu: CONTINUE at $($pt -join ',')"
}

function Load {
  $wsBefore = LineCount $wsLog
  $pt = FindWord '^CON[A-Z]{3,6}E$'
  if (-not $pt) { throw "CONTINUE not on screen" }
  & $desk -Proc Cyberpunk2077 -AtX $pt[0] -AtY $pt[1] -Click -WaitMs 300 | Out-Null
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt 240) {
    $new = LinesSince $wsLog $wsBefore
    if ($new -match 'done') { break }
    Start-Sleep 2
  }
  $new = LinesSince $wsLog $wsBefore
  Shot 'after_load' | Out-Null
  $hud = & $ocr -Full -Words | ForEach-Object { ($_ -split "`t") } | Out-Null
  $weaponEvents = @($new | Where-Object { $_ -match 'hand:|active:|armed:' -and $_ -notmatch '-> (nothing|none|false)$' -and $_ -notmatch ': - -> ' })
  [pscustomobject]@{ loaded = [bool]($new -match 'player attached'); probeLines = $new.Count; weaponDrawn = ($new -match 'hand: .* -> Items\.' -or $new -match 'active: .* -> Items\.').Count -gt 0; log = ($new -join ' | ') }
}

function Backpack {
  $miBefore = LineCount $miLog
  Key 'I' ; Start-Sleep 2
  $pt = WaitWord '^BACKPACK$' 15
  if ($pt) { & $desk -Proc Cyberpunk2077 -AtX $pt[0] -AtY $pt[1] -Click -WaitMs 1500 | Out-Null }
  $x = if ($ItemX -ge 0) { $ItemX } else { $DefaultItem[0] }
  $y = if ($ItemY -ge 0) { $ItemY } else { $DefaultItem[1] }
  & $desk -Proc Cyberpunk2077 -AtX $x -AtY $y -WaitMs 500 | Out-Null
  Shot 'bp_0' | Out-Null
  $half = [int]($HoverS / 2)
  Start-Sleep $half; Shot 'bp_1' | Out-Null
  Start-Sleep ($HoverS - $half); Shot 'bp_2' | Out-Null
  $new = LinesSince $miLog $miBefore
  $ins = @($new | Where-Object { $_ -match 'hover IN' }).Count
  $outs = @($new | Where-Object { $_ -match 'hover OUT' }).Count
  $modes = @($new | Where-Object { $_ -match 'input mode' }).Count
  Key 'ESC'; Start-Sleep 1; Key 'ESC'
  [pscustomobject]@{ hoverIn = $ins; hoverOut = $outs; modeFlips = $modes; flicker = ($ins -ge 3 -or $outs -ge 3); log = ($new -join ' | ') }
}

function Quit {
  Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 5
  "quit"
}

switch ($Step) {
  'launch' { Launch }
  'load' { Load }
  'backpack' { Backpack }
  'quit' { Quit }
  'all' {
    $l = Launch; $ld = Load; $bp = Backpack; Quit | Out-Null
    [pscustomobject]@{ loaded = $ld.loaded; weaponDrawn = $ld.weaponDrawn; flicker = $bp.flicker; hoverIn = $bp.hoverIn; hoverOut = $bp.hoverOut; modeFlips = $bp.modeFlips }
  }
}
