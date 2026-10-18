# Reads the text in a screen region with the built-in Windows OCR engine (Windows.Media.Ocr).
# Coordinates are relative to the given process's main window unless -Abs is set.
# -Words: output one line per word as "text<TAB>screenX<TAB>screenY" (centre of the word, absolute screen pixels).
# -Full: capture the whole primary screen (ignores X/Y/W/H).
param([string]$Proc = "Vortex", [int]$X, [int]$Y, [int]$W, [int]$H, [switch]$Abs, [string]$SavePng = "", [switch]$Words, [switch]$Full, [double]$Scale = 1.0)   # -Scale 2 enlarges small text before OCR
Add-Type -AssemblyName System.Drawing, System.Runtime.WindowsRuntime
if (-not ([System.Management.Automation.PSTypeName]'OcrWinRect').Type) {
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class OcrWinRect { [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Ri,B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r); }
"@
}
if ($Full) {
  Add-Type -AssemblyName System.Windows.Forms
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $X = $b.X; $Y = $b.Y; $W = $b.Width; $H = $b.Height
} elseif (-not $Abs) {
  $p = Get-Process $Proc -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { return "" }
  $r = New-Object OcrWinRect+R; [OcrWinRect]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $X += $r.L; $Y += $r.T
}
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($X, $Y, 0, 0, (New-Object System.Drawing.Size $W, $H)); $g.Dispose()
if ($Scale -ne 1.0) {
  $big = New-Object System.Drawing.Bitmap ([int]($W * $Scale)), ([int]($H * $Scale))
  $g2 = [System.Drawing.Graphics]::FromImage($big)
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.DrawImage($bmp, 0, 0, $big.Width, $big.Height); $g2.Dispose(); $bmp.Dispose(); $bmp = $big
}
$tmp = if ($SavePng) { $SavePng } else { "$env:TEMP\claude\ocr_tmp_$PID_$([guid]::NewGuid().ToString('N').Substring(0,8)).png" }
$bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(); $task.Result }
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$sb = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$res = Await ($engine.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
$stream.Dispose()
if (-not $SavePng) { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
if ($Words) {
  foreach ($l in $res.Lines) { foreach ($wd in $l.Words) {
    $r2 = $wd.BoundingRect
    "{0}`t{1}`t{2}" -f $wd.Text, [int]($X + ($r2.X + $r2.Width / 2) / $Scale), [int]($Y + ($r2.Y + $r2.Height / 2) / $Scale)
  } }
} else {
  ($res.Lines | ForEach-Object { $_.Text }) -join "`n"
}
