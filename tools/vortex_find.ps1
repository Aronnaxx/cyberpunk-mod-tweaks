# Vortex Mods tab helper: put text in the Mod Name filter, then report the visible rows.
# The filter box is found by OCR (the "Mod Name" column header), so window moves and column changes don't
# matter. Existing filter text is selected with a triple-click (never Ctrl+A: if focus is in the table,
# Ctrl+A selects every mod).
# Output: one line per OCR'd row word "text<TAB>x<TAB>y" for words right of the status toggles, plus
# "TOGGLE_X=<x>" = absolute x of the status toggle column (rows: click TOGGLE_X at the row's y).
param([string]$Name)
$d = "$PSScriptRoot\desk.ps1"
$ocr = "$PSScriptRoot\ocr_region.ps1"
$words = @(& $ocr -Proc Vortex -X 0 -Y 0 -W 2400 -H 400 -Words -Scale 2)
$hdr = $null
for ($i = 0; $i -lt $words.Count - 1; $i++) {
  $a = $words[$i] -split "`t"; $b = $words[$i + 1] -split "`t"
  if ($a[0] -eq 'Mod' -and $b[0] -like 'Name*') { $hdr = $a; break }
}
if (-not $hdr) { "ERROR: Mod Name header not found"; exit 1 }
$fx = [int]$hdr[1] + 60; $fy = [int]$hdr[2] + 22
& $d -Proc Vortex -AtX $fx -AtY $fy -Click -WaitMs 120 | Out-Null
& $d -Proc Vortex -AtX $fx -AtY $fy -Click -WaitMs 60 | Out-Null
& $d -Proc Vortex -AtX $fx -AtY $fy -Click -WaitMs 150 | Out-Null   # triple-click selects the old text
& $d -Proc Vortex -Type $Name -WaitMs 1500 -Shot -ShotName vortex | Out-Null
"FILTER_AT=$fx,$fy"
"TOGGLE_X=$([int]$hdr[1] - 120)"
