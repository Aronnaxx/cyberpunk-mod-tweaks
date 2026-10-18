<#
  CP2077 Mode Launcher v2 - asks "VR or Flat?" at game launch and keeps the two
  setting sets fully separate.
  Flat is the resting state: outside a VR session the game folder is exactly
  what Vortex deployed and flat settings are live, so Vortex never sees external
  changes and a plain Steam launch is always flat. A VR session installs the port
  (from the repacked zip, Vortex-free), applies the saved VR state, and when the
  game exits saves everything the port changed and puts flat back.
  Make sure the VR port is NOT enabled in Vortex.

  Per-mode state (in %LOCALAPPDATA%\CP2077ModeLauncher):
    flat\UserSettings.json, vr\UserSettings.json   game settings
    vr\game\...                                     vrport.ini, vrport-launcher.ini, calibration,
                                                    VR CET mod settings (anything the port writes)
  "RESET ALL VR SETTINGS" in the picker clears the VR set (kept in backups\vr-reset-*).

  Usage
    Steam launch options:
      powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "<this file>" %command%
    Or run directly (starts the game through Steam):
      CP2077-ModeLauncher.ps1 [-Mode flat|vr|reset] [-NoLaunch] [-Force]
#>
param(
    [ValidateSet('', 'flat', 'vr', 'reset')][string]$Mode = '',
    [switch]$NoLaunch,
    [switch]$Force,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameCmd
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Game = 'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
$CfgDir = Join-Path $env:LOCALAPPDATA 'CD Projekt Red\Cyberpunk 2077'
$Store = Join-Path $env:LOCALAPPDATA 'CP2077ModeLauncher'
$VrDll = Join-Path $Game 'red4ext\plugins\CyberpunkVR_Stereo\CyberpunkVR_Stereo.dll'
$StateFile = Join-Path $Store 'state.json'
$LogFile = Join-Path $Store 'launcher.log'

New-Item -ItemType Directory -Force -Path $Store, "$Store\flat", "$Store\vr", "$Store\backups" | Out-Null
function Log($m) { try { Add-Content -Path $LogFile -Value ("{0:s} {1}" -f (Get-Date), $m) } catch {} }
Log "start mode='$Mode' args=$($GameCmd.Count)"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -Namespace Win -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
'@

function Msg($text, $buttons = 'OK', $icon = 'Information') {
    [System.Windows.Forms.MessageBox]::Show($text, 'Cyberpunk Mode Launcher', $buttons, $icon)
}

# ============================== neon UI ==============================
$Col = @{
    Bg    = [Drawing.Color]::FromArgb(10, 10, 20)
    Panel = [Drawing.Color]::FromArgb(22, 22, 40)
    Yel   = [Drawing.Color]::FromArgb(252, 238, 10)
    Cyn   = [Drawing.Color]::FromArgb(0, 240, 255)
    Mag   = [Drawing.Color]::FromArgb(255, 42, 109)
    Dim   = [Drawing.Color]::FromArgb(120, 125, 160)
}
function Fnt($name, $size, $style = 'Regular') { New-Object Drawing.Font($name, [single]$size, [Drawing.FontStyle]$style) }
$FHead = Fnt 'Bahnschrift SemiBold' 11
$FBig = Fnt 'Bahnschrift SemiBold' 20
$FMono = Fnt 'Consolas' 10
$FMonoB = Fnt 'Consolas' 12 'Bold'
$FSmall = Fnt 'Consolas' 9

function Set-DoubleBuffered($c) {
    $c.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($c, $true)
}

function New-NeonForm([int]$w, [int]$h, [string]$title) {
    $f = New-Object Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.StartPosition = 'CenterScreen'
    $f.ClientSize = New-Object Drawing.Size($w, $h)
    $f.BackColor = $Col.Bg; $f.TopMost = $true; $f.Tag = $title
    $f.Icon = $script:AppIcon
    Set-DoubleBuffered $f
    $cut = 18
    $pts = [Drawing.Point[]]@(
        (New-Object Drawing.Point($cut, 0)), (New-Object Drawing.Point($w, 0)), (New-Object Drawing.Point($w, ($h - $cut))),
        (New-Object Drawing.Point(($w - $cut), $h)), (New-Object Drawing.Point(0, $h)), (New-Object Drawing.Point(0, $cut)))
    $gp = New-Object Drawing.Drawing2D.GraphicsPath; $gp.AddPolygon($pts)
    $f.Region = New-Object Drawing.Region($gp)
    $f.Add_Paint({
            param($s, $e)
            $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
            $w = $s.ClientSize.Width; $h = $s.ClientSize.Height; $cut = 18
            $p = [Drawing.Point[]]@((New-Object Drawing.Point($cut, 1)), (New-Object Drawing.Point(($w - 1), 1)), (New-Object Drawing.Point(($w - 1), ($h - $cut))),
                (New-Object Drawing.Point(($w - $cut), ($h - 1))), (New-Object Drawing.Point(1, ($h - 1))), (New-Object Drawing.Point(1, $cut)))
            $g.DrawPolygon((New-Object Drawing.Pen($Col.Yel, 2)), $p)
            $g.FillRectangle((New-Object Drawing.SolidBrush($Col.Mag)), ($w - 70), 0, 70, 4)       # magenta tick, top right
            $g.FillRectangle((New-Object Drawing.SolidBrush($Col.Cyn)), 0, ($h - 4), 90, 4)        # cyan tick, bottom left
            $g.DrawString([string]$s.Tag, $FHead, (New-Object Drawing.SolidBrush($Col.Yel)), 26, 12)
            $g.DrawLine((New-Object Drawing.Pen($Col.Dim, 1)), 24, 38, ($w - 24), 38)
        })
    $drag = @{ on = $false; x = 0; y = 0 }
    $f.Add_MouseDown({ param($s, $e) $drag.on = $true; $drag.x = $e.X; $drag.y = $e.Y }.GetNewClosure())
    $f.Add_MouseUp({ $drag.on = $false }.GetNewClosure())
    $f.Add_MouseMove({ param($s, $e) if ($drag.on) { $s.Left += $e.X - $drag.x; $s.Top += $e.Y - $drag.y } }.GetNewClosure())
    return $f
}

function New-Label($text, $font, $color, $x, $y, $w, $h) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text; $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [Drawing.Color]::Transparent
    $l.Location = New-Object Drawing.Point($x, $y); $l.Size = New-Object Drawing.Size($w, $h)
    return $l
}

function New-NeonButton($text, $color, $x, $y, $w, $h, $font) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.Font = $font; $b.Tag = $color
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 2; $b.FlatAppearance.BorderColor = $color
    $b.FlatAppearance.MouseOverBackColor = $color; $b.FlatAppearance.MouseDownBackColor = $Col.Yel
    $b.BackColor = $Col.Panel; $b.ForeColor = $color; $b.UseVisualStyleBackColor = $false
    $b.Location = New-Object Drawing.Point($x, $y); $b.Size = New-Object Drawing.Size($w, $h)
    $b.Add_MouseEnter({ $this.ForeColor = $Col.Bg })
    $b.Add_MouseLeave({ $this.ForeColor = $this.Tag })
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    return $b
}

# icon (generated by make-icon.ps1); falls back to none
$script:AppIcon = $null
try { $ip = Join-Path $Here 'cp2077-mode.ico'; if (Test-Path $ip) { $script:AppIcon = New-Object Drawing.Icon($ip) } } catch {}

function Show-Picker($last) {
    $f = New-NeonForm 540 340 '// CYBERPUNK 2077  ::  LOADOUT'
    $f.Controls.Add((New-Label 'SELECT RENDER MODE' $FMonoB $Col.Cyn 26 50 400 24))
    $script:picked = ''
    $defs = @(
        @{ t = "FLAT`n[ MONITOR ]"; m = 'flat'; c = $Col.Cyn; x = 26 },
        @{ t = "VR`n[ HEADSET ]"; m = 'vr'; c = $Col.Mag; x = 281 })
    foreach ($d in $defs) {
        $b = New-NeonButton $d.t $d.c $d.x 84 233 112 $FBig
        $b.Name = $d.m
        $b.Add_Click({ $script:picked = $this.Name; $this.FindForm().Close() })
        $f.Controls.Add($b)
        if ($d.m -eq $last) {
            $f.AcceptButton = $b
            $f.Controls.Add((New-Label '>> LAST USED' $FSmall $Col.Yel $d.x 200 150 18))
        }
    }
    $rb = New-NeonButton 'RESET ALL VR SETTINGS' $Col.Mag 26 230 488 40 $FMonoB
    $rb.Name = 'reset'
    $rb.Add_Click({ $script:picked = $this.Name; $this.FindForm().Close() })
    $f.Controls.Add($rb)
    $foot = "ENTER = LAST USED    ESC = ABORT"
    $f.Controls.Add((New-Label $foot $FSmall $Col.Dim 26 296 480 18))
    $esc = New-Object Windows.Forms.Button; $esc.Size = New-Object Drawing.Size(1, 1); $esc.Location = New-Object Drawing.Point(-10, -10)
    $esc.Add_Click({ $this.FindForm().Close() }); $f.Controls.Add($esc); $f.CancelButton = $esc
    $f.Add_Shown({ $this.Activate() })
    [void]$f.ShowDialog()
    return $script:picked
}

# ---- progress window ----
$script:P = $null
function Show-Progress($title) {
    $f = New-NeonForm 580 250 $title
    $P = @{ Form = $f; Pct = -1; Tick = 0; Start = Get-Date }
    $P.Phase = New-Label '> INITIALIZING' $FMonoB $Col.Cyn 26 52 530 24
    $P.Bar = New-Object Windows.Forms.Panel
    $P.Bar.Location = New-Object Drawing.Point(26, 92); $P.Bar.Size = New-Object Drawing.Size(528, 30); $P.Bar.BackColor = $Col.Bg
    Set-DoubleBuffered $P.Bar
    $P.Bar.Add_Paint({
            param($s, $e)
            $g = $e.Graphics; $n = 48; $gap = 3
            $sw = ($s.Width - ($n - 1) * $gap) / $n
            $pct = $script:P.Pct
            $filled = if ($pct -ge 0) { [math]::Floor($pct / 100 * $n) } else { 0 }
            $scan = $script:P.Tick % ($n + 8)
            for ($i = 0; $i -lt $n; $i++) {
                $x = $i * ($sw + $gap)
                if ($pct -ge 0) { $c = if ($i -lt $filled) { $Col.Yel } else { $Col.Panel } }
                else { $c = if ($i -le $scan -and $i -gt $scan - 6) { $Col.Cyn } else { $Col.Panel } }
                $g.FillRectangle((New-Object Drawing.SolidBrush($c)), [single]$x, 0, [single]$sw, $s.Height)
            }
        })
    $P.Pct_l = New-Label '' $FMonoB $Col.Yel 440 126 114 22; $P.Pct_l.TextAlign = 'MiddleRight'
    $P.Elapsed = New-Label 'T+00:00' $FSmall $Col.Dim 26 130 120 18
    $P.Detail = New-Label '' $FSmall $Col.Dim 26 156 528 34
    $P.Hint = New-Label '' $FMono $Col.Mag 26 196 528 40
    foreach ($c in $P.Bar, $P.Phase, $P.Pct_l, $P.Elapsed, $P.Detail, $P.Hint) { $f.Controls.Add($c) }
    $script:P = $P
    $f.Show(); $f.Activate()
}
function Set-Progress($phase, $pct = $null, $detail = $null, $hint = $null) {
    $P = $script:P; if (-not $P) { return }
    if ($phase) { $P.Phase.Text = "> $phase" }
    if ($null -ne $pct) { $P.Pct = $pct; $P.Pct_l.Text = if ($pct -ge 0) { '{0:0}%' -f $pct } else { '' } }
    if ($null -ne $detail) { $P.Detail.Text = $detail }
    if ($null -ne $hint) { $P.Hint.Text = $hint }
}
function Pump([double]$seconds = 0.05) {
    $end = (Get-Date).AddSeconds($seconds)
    do {
        $P = $script:P
        if ($P) {
            $P.Tick++; $t = (Get-Date) - $P.Start
            $P.Elapsed.Text = 'T+{0:00}:{1:00}' -f [int][math]::Floor($t.TotalMinutes), $t.Seconds
            $P.Bar.Invalidate()
        }
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 40
    } while ((Get-Date) -lt $end)
}
function Close-Progress { if ($script:P) { $script:P.Form.Close(); $script:P = $null } }

# ============================== settings sets ==============================
# flat\UserSettings.json  - flat game settings
# vr\UserSettings.json    - VR game settings (absent = start from flat + the port's first-launch preset)
# vr\game\...             - every VR port file changed or created at runtime (vrport.ini, launcher ini,
#                           calibration, CET mod databases/configs), mirrored by game-relative path
$LiveUS = Join-Path $CfgDir 'UserSettings.json'
$VrState = Join-Path $Store 'vr\game'
$PortLogs = Join-Path $Store 'logs'

function Prune-Backups {
    Get-ChildItem "$Store\backups" -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip 30 | Remove-Item -Force
    Get-ChildItem "$Store\backups" -Directory -Filter 'vr-reset-*' | Sort-Object Name -Descending | Select-Object -Skip 3 | Remove-Item -Recurse -Force
}

function Save-US($mode) {
    if (-not (Test-Path $LiveUS)) { return }
    New-Item -ItemType Directory -Force -Path "$Store\$mode" | Out-Null
    Copy-Item $LiveUS "$Store\$mode\UserSettings.json" -Force
    Log "saved UserSettings -> $mode"
}

function Load-US($mode) {
    $src = "$Store\$mode\UserSettings.json"
    if (-not (Test-Path $src)) { Log "no $mode UserSettings yet, keeping live"; return }
    if (Test-Path $LiveUS) { Copy-Item $LiveUS "$Store\backups\$(Get-Date -Format 'yyyyMMdd-HHmmss')-UserSettings.json" -Force }
    Prune-Backups
    Copy-Item $src $LiveUS -Force
    Log "loaded $mode UserSettings"
}

# Fresh VR set: the port merges its preset into UserSettings.json only after the game has read it,
# so that first session would run on flat graphics (path tracing + DLAA at headset resolution froze
# on load 10-13). Apply the preset's graphics/video/performance values before launching instead.
function Merge-VrPreset {
    $preset = Join-Path $Game 'red4ext\plugins\CyberpunkVR_Stereo\UserSettings.json'
    if (-not (Test-Path $preset) -or -not (Test-Path $LiveUS)) { return }
    $p = [IO.File]::ReadAllText($preset) | ConvertFrom-Json
    $l = [IO.File]::ReadAllText($LiveUS) | ConvertFrom-Json
    $n = 0
    foreach ($pg in $p.data) {
        if ($pg.group_name -notmatch '^/(graphics|video)/|^/gameplay/performance$') { continue }
        $lg = $l.data | Where-Object { $_.group_name -eq $pg.group_name } | Select-Object -First 1
        if (-not $lg) { continue }
        foreach ($po in $pg.options) {
            $lo = $lg.options | Where-Object { $_.name -eq $po.name } | Select-Object -First 1
            if ($lo -and "$($lo.value)" -ne "$($po.value)") { $lo.value = $po.value; $n++ }
        }
    }
    if ($n) {
        [IO.File]::WriteAllText($LiveUS, ($l | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
        Log "fresh VR set: applied $n port preset graphics values before launch"
    }
}

# Settings that break the headset image with this port, forced off on every VR launch.
function Set-VrSafety {
    if (-not (Test-Path $LiveUS)) { return }
    $text = [IO.File]::ReadAllText($LiveUS)
    $orig = $text
    foreach ($kv in @(@('HDRModes', '"None"'), @('FrameGeneration', '"Off"'), @('DLSSFrameGen', 'false'))) {
        $rx = New-Object Text.RegularExpressions.Regex ('("name"\s*:\s*"' + $kv[0] + '"\s*,[^{}]*?"value"\s*:\s*)("[^"]*"|true|false)')
        $text = $rx.Replace($text, ('${1}' + $kv[1]), 1)
    }
    if ($text -ne $orig) {
        [IO.File]::WriteAllText($LiveUS, $text, (New-Object Text.UTF8Encoding $false))
        Log 'VR safety: forced HDR off / frame generation off'
    }
}

function Get-State {
    $s = @{ live = 'flat'; last = 'flat' }
    if (Test-Path $StateFile) {
        $j = Get-Content $StateFile -Raw | ConvertFrom-Json
        if ($j.live) { $s.live = $j.live } elseif ($j.last) { $s.live = $j.last }   # v1 only had 'last' (= live set)
        if ($j.last) { $s.last = $j.last }
    }
    return $s
}
function Set-State($live, $last) { @{ live = $live; last = $last } | ConvertTo-Json | Set-Content $StateFile }

# v1 layout -> v2: vr-modified\ and the vrport inis move into vr\game\
function Migrate-Legacy {
    $old = Join-Path $Store 'vr-modified'
    if (Test-Path $old) {
        foreach ($f in Get-ChildItem $old -Recurse -File) {
            $dst = Join-Path $VrState $f.FullName.Substring($old.Length + 1)
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            if (-not (Test-Path $dst)) { Move-Item $f.FullName $dst }
        }
        Remove-Item $old -Recurse -Force
        Log 'migrated vr-modified -> vr\game'
    }
    foreach ($k in 'vrport.ini', 'vrport-launcher.ini') {
        $v = Join-Path "$Store\vr" $k; $dst = Join-Path $VrState "bin\x64\$k"
        if (Test-Path $v) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            if (-not (Test-Path $dst)) { Move-Item $v $dst } else { Remove-Item $v -Force }
            Log "migrated vr\$k -> vr\game"
        }
        $f = Join-Path "$Store\flat" $k   # flat never needs VR port files
        if (Test-Path $f) { Move-Item $f "$Store\backups\flat-legacy-$k" -Force }
    }
}

# ============================== VR port overlay (Vortex-free) ==============================
# The launcher owns the VR port's files: it copies them from the repacked zip into the game folder
# when a VR session starts and removes them (saving anything the port changed into vr\game) when
# the game exits. Outside a VR session the game folder is exactly what Vortex deployed.
#   vr-backup : files that already existed where the port writes - restored on disable
$VrZip = Join-Path $Store 'vr-port.zip'
$VrBackup = Join-Path $Store 'vr-backup'
$CetMods = Join-Path $Game 'bin\x64\plugins\cyber_engine_tweaks\mods'
# files the port creates outside its own folders
$VrLooseFiles = 'bin\x64\vrport.ini', 'bin\x64\vrport-launcher.ini', 'bin\x64\vrik_bone_resolve.txt', 'bin\x64\CyberpunkVR_SmokeGrip_loadinfo.txt', 'bin\x64\cyberpunkvr_sight_ps.bin'
$VrLogFile = 'bin\x64\cyberpunkvrport.log'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-EntryHash($entry) {
    $s = $entry.Open()
    try { return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($s))).Replace('-', '') }
    finally { $s.Dispose() }
}

# Port build to use. Tofu Express TE6 (dabinn fork); to go back to the original port, point this at
# ..\CyberpunkVRPort-0.1.7-vortex.zip (the cached copy is swapped on the next launcher run).
$VrZipSrc = Join-Path $Here '..\CyberpunkVRPort-0.1.7-TE6-ported.zip'

# Game-relative path of a zip entry, or $null for entries that are not game files. FOMOD-style
# zips (TE6) put the game files under "Cyberpunk 2077/" next to INSTALL.txt, UNINSTALL.bat, fomod/.
function Get-EntryRel($entry) {
    $p = $entry.FullName -replace '\\', '/'
    if ($p -match '^Cyberpunk 2077/(.+)$') { $p = $Matches[1] }
    elseif ($p -notmatch '^(archive|bin|engine|r6|red4ext|mods)/') { return $null }
    return $p -replace '/', '\'
}
function Get-VrEntries($zip) { @($zip.Entries | Where-Object { $_.Name -and (Get-EntryRel $_) }) }

function Open-VrZip {
    if (-not (Test-Path $VrZip)) {
        if (-not (Test-Path $VrZipSrc)) { throw "VR port zip not found at $VrZipSrc" }
        Copy-Item $VrZipSrc $VrZip
    }
    return [IO.Compression.ZipFile]::OpenRead($VrZip)
}

# Refresh the cached zip when the source changed (a repack or port update). Only while the port is
# not deployed: removal walks the cached zip, so it must be the one the deployed files came from.
function Sync-VrZip {
    if (-not (Test-Path $VrZipSrc) -or -not (Test-Path $VrZip) -or (Test-Path $VrDll)) { return }
    $s = Get-Item $VrZipSrc; $c = Get-Item $VrZip
    if ($s.Length -eq $c.Length -and $s.LastWriteTimeUtc -eq $c.LastWriteTimeUtc) { return }
    Copy-Item $VrZipSrc $VrZip -Force
    Log "VR port zip refreshed from $VrZipSrc"
}

# Fixes to the port's own files (vr-patches\ mirrors game-relative paths). Copied over the stock file
# after extraction; on removal a file still matching its patch counts as stock, not as VR state.
$VrPatches = Join-Path $Here 'vr-patches'
function Get-PatchFile($rel) { $p = Join-Path $VrPatches $rel; if (Test-Path $p -PathType Leaf) { $p } }

# folders that belong to the port alone (anything inside them is VR state)
function Get-VrOwnedDirs {
    $d = @(Join-Path $Game 'red4ext\plugins\CyberpunkVR_Stereo')
    if (Test-Path $CetMods) { $d += @(Get-ChildItem $CetMods -Directory -Filter 'CyberpunkVRPort_*' | ForEach-Object FullName) }
    return @($d | Where-Object { Test-Path $_ })
}

# ---- mods parked while in VR mode (see vr-disable.txt) ----
# Only for the length of a VR session; Vortex would flag them as externally deleted if it were
# opened mid-session (answer "Revert", never "Save"), but at rest everything is back in place.
$VrOffList = Join-Path $Here 'vr-disable.txt'
$VrOffStash = Join-Path $Store 'vr-off'
function Get-VrOff { if (Test-Path $VrOffList) { @(Get-Content $VrOffList | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) } else { @() } }
function Stash-VrOff {
    foreach ($rel in Get-VrOff) {
        $src = Join-Path $Game $rel; $dst = Join-Path $VrOffStash $rel
        if (-not (Test-Path $src)) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Move-Item $src $dst -Force
        Log "parked $rel"
    }
}
function Restore-VrOff {
    foreach ($rel in Get-VrOff) {
        $src = Join-Path $VrOffStash $rel; $dst = Join-Path $Game $rel
        if (-not (Test-Path $src)) { continue }
        if (Test-Path $dst) { Remove-Item $src -Recurse -Force; Log "$rel already redeployed, dropped parked copy"; continue }
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        Move-Item $src $dst -Force
        Log "restored $rel"
    }
}

function Enable-VrPort {
    Set-Progress 'INSTALLING VR PORT' 0 '' ''
    $zip = Open-VrZip
    try {
        $entries = Get-VrEntries $zip
        $n = 0
        foreach ($e in $entries) {
            $rel = Get-EntryRel $e
            $dst = Join-Path $Game $rel
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            if (Test-Path $dst) {
                $bk = Join-Path $VrBackup $rel
                if (-not (Test-Path $bk)) { New-Item -ItemType Directory -Force -Path (Split-Path $bk) | Out-Null; Copy-Item $dst $bk -Force }
            }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dst, $true)
            $patch = Get-PatchFile $rel
            if ($patch) { Copy-Item $patch $dst -Force; Log "patched $rel" }
            $n++
            if ($n % 4 -eq 0) { Set-Progress $null (90.0 * $n / $entries.Count) $rel; Pump 0.005 }
        }
    }
    finally { $zip.Dispose() }
    # your VR settings / calibration / CET mod state on top of the stock files
    Set-Progress 'APPLYING VR SETTINGS' 92 ''
    $k = 0
    if (Test-Path $VrState) {
        foreach ($f in Get-ChildItem $VrState -Recurse -File) {
            $dst = Join-Path $Game $f.FullName.Substring($VrState.Length + 1)
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $f.FullName $dst -Force; $k++
        }
    }
    Set-Progress 'PARKING RENDER MODS' 96 ''
    Stash-VrOff
    Set-Progress 'VR PORT INSTALLED' 100 "$($entries.Count) files, $k saved VR files"
    Log "VR port enabled ($($entries.Count) files, $k from vr\game)"
}

function Save-VrFile($abs) {
    if ($script:VrForeign) { return }   # files from an install the launcher didn't make are not VR state
    $dst = Join-Path $VrState $abs.Substring($Game.Length + 1)
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item $abs $dst -Force
}

function Disable-VrPort {
    Set-Progress 'SAVING VR STATE + REMOVING VR PORT' 0 '' ''
    $zip = Open-VrZip
    $dirs = @{}
    $inZip = @{}
    try {
        $entries = Get-VrEntries $zip
        $n = 0
        foreach ($e in $entries) {
            $rel = Get-EntryRel $e
            $inZip[$rel.ToLowerInvariant()] = 1
            $dst = Join-Path $Game $rel
            if (Test-Path $dst) {
                $kept = Join-Path $VrState $rel
                $patch = Get-PatchFile $rel
                $stock = if ($patch) { (Get-FileHash $patch -Algorithm SHA256).Hash } else { Get-EntryHash $e }
                if ((Get-FileHash $dst -Algorithm SHA256).Hash -ne $stock) { Save-VrFile $dst }
                elseif ((Test-Path $kept) -and -not $script:VrForeign) { Remove-Item $kept -Force }   # back to stock
                Remove-Item $dst -Force
            }
            $bk = Join-Path $VrBackup $rel
            if (Test-Path $bk) { Copy-Item $bk $dst -Force; Remove-Item $bk -Force }
            $dirs[(Split-Path $dst)] = 1
            $n++
            if ($n % 4 -eq 0) { Set-Progress $null (80.0 * $n / $entries.Count) $rel; Pump 0.005 }
        }
    }
    finally { $zip.Dispose() }
    # files the port created at runtime inside its own folders
    foreach ($d in Get-VrOwnedDirs) {
        foreach ($f in Get-ChildItem $d -Recurse -File) {
            $rel = $f.FullName.Substring($Game.Length + 1)
            if ($inZip.ContainsKey($rel.ToLowerInvariant())) { continue }
            if ($f.Extension -ne '.log') { Save-VrFile $f.FullName }
            $dirs[$f.DirectoryName] = 1
            Remove-Item $f.FullName -Force
        }
    }
    foreach ($rel in $VrLooseFiles) {
        $p = Join-Path $Game $rel
        if (Test-Path $p) { Save-VrFile $p; Remove-Item $p -Force }
    }
    $lp = Join-Path $Game $VrLogFile
    if (Test-Path $lp) {
        New-Item -ItemType Directory -Force -Path $PortLogs | Out-Null
        Move-Item $lp (Join-Path $PortLogs ("cyberpunkvrport-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))) -Force
        Get-ChildItem $PortLogs -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force
    }
    # prune directories the port left empty (never touches non-empty ones, e.g. Vortex marker dirs)
    foreach ($d in ($dirs.Keys | Sort-Object Length -Descending)) {
        $p = $d
        while ($p.Length -gt $Game.Length -and (Test-Path $p) -and -not (Get-ChildItem $p -Force | Select-Object -First 1)) {
            Remove-Item $p -Force; $p = Split-Path $p
        }
    }
    Set-Progress 'RESTORING RENDER MODS' 90 ''
    Restore-VrOff
    Set-Progress 'VR PORT REMOVED' 100 "$($entries.Count) files"
    Log "VR port disabled ($($entries.Count) files)"
}

# Put the game back to its resting state: flat settings live, VR port removed, render mods back.
# Runs after every VR session and at startup (covers a crash, a killed launcher or the v1 launcher).
function Return-ToFlat($st) {
    $deployed = Test-Path $VrDll
    $parked = (Test-Path $VrOffStash) -and (Get-ChildItem $VrOffStash -Recurse -File | Select-Object -First 1)
    if (-not $deployed -and -not $parked -and $st.live -eq 'flat') { return }
    Show-Progress '// LOADOUT RESET  ::  FLAT'
    # 'vr-pending' = interrupted while switching: live settings may be half VR, so don't keep them as the VR set
    if ($st.live -eq 'vr') { Save-US 'vr' }
    # Port present while we're at rest = installed outside the launcher (the port's auto installer,
    # Vortex, by hand). Remove it without keeping any of its files, and reload flat settings: its
    # first launch merges the VR preset into the live UserSettings (10-14 auto installer).
    $script:VrForeign = $deployed -and $st.live -eq 'flat'
    if ($script:VrForeign) { Log 'VR port found outside a VR session (installed outside the launcher) - removing it, keeping none of its files' }
    try { if ($deployed) { Disable-VrPort } else { Restore-VrOff } }
    finally { $script:VrForeign = $false }
    if ($st.live -ne 'flat' -or $deployed) { Load-US 'flat' }
    Set-State 'flat' $st.last
    $st.live = 'flat'
    Set-Progress 'FLAT LOADOUT RESTORED' 100 ''
    Pump 0.6
    Close-Progress
}

function Reset-VrSettings {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if (Test-Path "$Store\vr") { Move-Item "$Store\vr" "$Store\backups\vr-reset-$stamp" }
    New-Item -ItemType Directory -Force -Path "$Store\vr" | Out-Null
    Prune-Backups
    Log "VR settings reset (old set kept in backups\vr-reset-$stamp)"
}

# ============================== main flow ==============================
# game must be closed before touching mod files
if (Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue) { [void](Msg "Cyberpunk 2077 is already running. Close it first, then launch again." 'OK' 'Warning'); exit 0 }

if (-not (Test-Path $StateFile)) { Save-US 'flat'; Set-State 'flat' 'flat'; Log 'first run, adopted live as flat' }
Migrate-Legacy
$st = Get-State
Return-ToFlat $st
Sync-VrZip

while ($true) {
    if (-not $Mode) { $Mode = Show-Picker $st.last }
    if (-not $Mode) { Log 'cancelled'; exit 0 }
    if ($Mode -ne 'reset') { break }
    $r = Msg ("Reset ALL VR settings?`n`nThis clears the VR port's config (vrport.ini, launcher resolution, world scale/IPD, body calibration, VR CET mod settings) and the VR game settings. The next VR launch starts from the port's own defaults, merged over your flat settings.`n`nFlat settings are not touched. The old VR set is kept in the launcher's backups folder.") 'YesNo' 'Warning'
    if ($r -eq 'Yes') { Reset-VrSettings; [void](Msg 'VR settings reset. The next VR launch starts from the port defaults.') }
    $Mode = ''
}
Log "picked $Mode"
$st.last = $Mode   # Return-ToFlat writes $st.last back, so this keeps "LAST USED" right after a VR session
Set-State 'flat' $Mode

if ($Mode -eq 'vr') {
    if (-not (Get-Process 'VirtualDesktop.Streamer' -ErrorAction SilentlyContinue) -and -not $Force) {
        $r = Msg ("Virtual Desktop Streamer doesn't seem to be running, and the VR port needs the headset connected first.`n`nLaunch anyway?") 'YesNo' 'Warning'
        if ($r -ne 'Yes') { exit 0 }
    }
    Show-Progress '// LOADOUT SWITCH  ::  VR'
    Save-US 'flat'
    Set-State 'vr-pending' 'vr'
    Enable-VrPort
    if (Test-Path "$Store\vr\UserSettings.json") { Load-US 'vr' } else { Merge-VrPreset }
    Set-VrSafety
    $st.live = 'vr'; Set-State 'vr' 'vr'
    Pump 0.6
    Close-Progress
}

if ($NoLaunch) { Log 'NoLaunch set, done (VR stays applied until the next launcher run)'; exit 0 }

# launch
if ($GameCmd -and $GameCmd.Count -gt 0) {
    $exe = $GameCmd[0]
    $rest = @($GameCmd | Select-Object -Skip 1 | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
    if ($rest.Count) { Start-Process -FilePath $exe -ArgumentList $rest -WorkingDirectory (Split-Path $exe) }
    else { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
}
else {
    Start-Process 'steam://rungameid/1091500'
}
Log "launched $Mode"

# flat is the resting state, so nothing to undo afterwards
if ($Mode -eq 'flat') { exit 0 }

# VR: stay resident and put everything back once the game exits
Show-Progress '// JACKING IN  ::  VR'
Set-Progress 'LAUNCHING CYBERPUNK 2077' -1 'Waiting for the game process...' 'Put the headset on once the game window appears.'
$proc = $null
for ($i = 0; $i -lt 300 -and -not $proc; $i++) {
    $proc = Get-Process 'Cyberpunk2077' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { Pump 1 }
}
Close-Progress
if ($proc) {
    do {
        $proc.WaitForExit()
        Start-Sleep -Seconds 3
        $proc = Get-Process 'Cyberpunk2077' -ErrorAction SilentlyContinue | Select-Object -First 1
    } while ($proc)
    Log 'game exited'
}
else { Log 'game process never appeared' }
# The port renders through a fixed set of camera components; a launcher resolution with no matching
# component falls back to another camera and gets resampled to the headset size (soft image).
$vrcamMiss = $null
try { $vrcamMiss = Select-String -Path (Join-Path $Game $VrLogFile) -Pattern 'GIVING UP on (vrcam_\S+).*Falling back to the live camera (vrcam_feed_\S+?)\.?$' | Select-Object -Last 1 } catch {}
Return-ToFlat $st
if ($vrcamMiss) {
    $want = $vrcamMiss.Matches[0].Groups[1].Value -replace '^vrcam_'; $got = $vrcamMiss.Matches[0].Groups[2].Value -replace '^vrcam_feed_'
    Log "vrcam mismatch: launcher $want, rendered $got"
    [void](Msg "The VR port's launcher resolution ($want) has no matching render camera, so the game rendered at $got and stretched it to $want - that makes the headset image soft.`n`nPick $got (or another listed size) in the VR port's launcher next session." 'OK' 'Warning')
}
if (-not $proc -and $i -ge 300) { [void](Msg 'The game never started, so the VR loadout was undone. Launch again when ready.' 'OK' 'Warning') }
