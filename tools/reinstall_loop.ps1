# Restores Vortex mods whose staging folders were emptied, by sending each mod's exact nxm:// link
# (Vortex downloads it with the logged-in Premium account, or reuses the archive already in downloads)
# and confirming "Replace the existing mod".
# Safety: the dialog is read with Windows OCR. It clicks ONLY when the text contains "Install options",
# "already installed" and "Replace the existing mod"; it stops at once if the text mentions external
# changes / save / delete / error, or after 3 consecutive timeouts. Resumable: mods whose staging folder
# already has files are skipped.
param(
  [string]$Table = "$env:USERPROFILE\Documents\cyberpunk-mod-patches\vortex-lost-mods-detail.json",
  [string]$Log = "$env:USERPROFILE\Documents\cyberpunk-mod-patches\reinstall-log.csv",
  [int]$TimeoutS = 120,
  [int]$Max = 10000,
  [int[]]$SkipModIds = @(34403)   # Advanced Crash Reporter: Vortex's ASI installer rejects it; handled by hand
)
$tools = $PSScriptRoot
$desk = "$tools\desk.ps1"
$ocr = "$tools\ocr_region.ps1"
$staging = "$env:APPDATA\Vortex\cyberpunk2077\mods"
$danger = 'External Changes|Save change|delete file|Error|Confirm|Name mod variant'

function FileCount($mod) {
  $p = Join-Path $staging $mod
  if (-not (Test-Path -LiteralPath $p)) { return 0 }
  @(Get-ChildItem -LiteralPath $p -Recurse -File | Where-Object Name -ne '__folder_managed_by_vortex').Count
}

function Note($msg) { "{0},""{1}""" -f (Get-Date -Format "HH:mm:ss"), $msg | Out-File $Log -Append -Encoding utf8 }

# Returns @(kind, text, clickX, clickY): kind is 'replace' (safe Replace dialog), 'danger' or 'none'.
# OCR covers the Vortex window minus the notification column on the left (rel x < 420), so toasts such as
# "Installation failed" don't count. The dialog can sit at different heights (e.g. stacked on a FOMOD window),
# so Continue is located relative to the dialog title (see below).
function ReadDialog {
  $words = @(& $ocr -Proc Vortex -X 420 -Y 0 -W 1680 -H 1220 -Words)
  if (-not $words) { return @('none', '', 0, 0) }
  $txt = ($words | ForEach-Object { ($_ -split "`t")[0] }) -join ' '
  if ($txt -match $danger) { return @('danger', $txt, 0, 0) }
  # OCR sometimes garbles 'installed' (e.g. 'instaued'), so anchor on 'already ... on your system' instead.
  if ($txt -match 'Install options' -and $txt -match 'already \S+ on your system' -and $txt -match 'Replace the existing mod') {
    # Anchor on the one-line title "Install options" (first occurrence = title, not the variant radio text);
    # Continue sits +558, +380 px from the centre of the word "Install". Long mod names wrap and move the
    # body text, but never the title or the buttons.
    for ($i = 0; $i -lt $words.Count - 1; $i++) {
      $a = $words[$i] -split "`t"; $b = ($words[$i + 1] -split "`t")[0]
      if ($a[0] -eq 'Install' -and $b -like 'options*') { return @('replace', $txt, ([int]$a[1] + 558), ([int]$a[2] + 380)) }
    }
  }
  return @('none', $txt, 0, 0)
}

function ClickReplace($x, $y) {
  # "Replace the existing mod" is Vortex's default choice and the OCR check confirmed this dialog.
  & $desk -Proc Vortex -AtX $x -AtY $y -Click -WaitMs 150 | Out-Null   # Continue (absolute screen point)
}

if (-not (Test-Path $Log)) { "time,mod,modId,fileId,result,files,seconds" | Out-File $Log -Encoding utf8 }
$rows = (Get-Content $Table -Raw | ConvertFrom-Json) | ForEach-Object { $_ } |
  Where-Object { $_.source -eq 'nexus' -and $_.modId -and $_.fileId -and ($SkipModIds -notcontains [int]$_.modId) }
Note "start: $(@($rows).Count) nexus rows"

$done = 0; $fails = 0; $consec = 0; $stopped = $false
foreach ($r in $rows) {
  if ($done -ge $Max -or $stopped) { break }
  $altDone = [IO.Path]::GetFileNameWithoutExtension([string]$r.fileName)
  if ((FileCount $r.mod) -gt 0 -or ($altDone -ne $r.mod -and (FileCount $altDone) -gt 0)) { continue }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Start-Process "nxm://cyberpunk2077/mods/$($r.modId)/files/$($r.fileId)"
  $result = "timeout"
  $lastPt = $null   # dialogs slide in: click only when two consecutive reads agree on the position
  # Mods updated in place keep their old folder name; a reinstall then lands in a folder named after the archive.
  $alt = [IO.Path]::GetFileNameWithoutExtension([string]$r.fileName)
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutS) {
    Start-Sleep -Milliseconds 700
    $d = ReadDialog
    if ($d[0] -eq 'danger') {
      & $desk -Proc Vortex -WaitMs 100 -Shot -ShotName "reinstall_STOP" | Out-Null
      Note ("STOP: unexpected dialog text: " + ($d[1] -replace '[\r\n"]', ' '))
      $result = "stopped"; $stopped = $true; break
    }
    if ($d[0] -eq 'replace') {
      if ($lastPt -and [Math]::Abs($lastPt[0] - $d[2]) -le 3 -and [Math]::Abs($lastPt[1] - $d[3]) -le 3) { ClickReplace $d[2] $d[3]; $lastPt = $null }
      else { $lastPt = @($d[2], $d[3]) }
    } else { $lastPt = $null }
    if ((FileCount $r.mod) -gt 0) { Start-Sleep -Milliseconds 800; $result = "ok"; break }
    if ($alt -and $alt -ne $r.mod -and (FileCount $alt) -gt 0) { Start-Sleep -Milliseconds 800; $result = "ok-newentry"; break }
  }
  "{0},""{1}"",{2},{3},{4},{5},{6}" -f (Get-Date -Format "HH:mm:ss"), $r.mod, $r.modId, $r.fileId, $result, (FileCount $r.mod), [int]$sw.Elapsed.TotalSeconds | Out-File $Log -Append -Encoding utf8
  $done++
  if ($result -like "ok*") { $consec = 0 }
  elseif (-not $stopped) {
    $fails++; $consec++
    & $desk -Proc Vortex -WaitMs 100 -Shot -ShotName "reinstall_timeout_$($r.modId)" | Out-Null
    if ($consec -ge 3) { Note "STOP: 3 consecutive timeouts"; $stopped = $true }
  }
}
Note "end: processed=$done failed=$fails stopped=$stopped"
"processed=$done failed=$fails stopped=$stopped"
