Add-Type -AssemblyName System.Drawing
$out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'cp2077-mode.ico'

function Draw([int]$n) {
    $bmp = New-Object System.Drawing.Bitmap $n, $n
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
    $u = $n / 256.0
    $yellow = [System.Drawing.Color]::FromArgb(252, 238, 10)
    $cyan = [System.Drawing.Color]::FromArgb(0, 240, 255)
    $mag = [System.Drawing.Color]::FromArgb(255, 42, 109)
    $bg = [System.Drawing.Color]::FromArgb(11, 11, 22)

    # rounded square background
    $r = 44 * $u
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rect = New-Object System.Drawing.RectangleF (8*$u), (8*$u), (240*$u), (240*$u)
    $path.AddArc($rect.X, $rect.Y, $r, $r, 180, 90)
    $path.AddArc($rect.Right - $r, $rect.Y, $r, $r, 270, 90)
    $path.AddArc($rect.Right - $r, $rect.Bottom - $r, $r, $r, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $bg), $path)
    $g.DrawPath((New-Object System.Drawing.Pen $yellow, ([Math]::Max(1, 8*$u))), $path)

    # headset body
    $pen = New-Object System.Drawing.Pen $yellow, ([Math]::Max(1, 14*$u))
    $pen.LineJoin = 'Round'
    $body = New-Object System.Drawing.RectangleF (46*$u), (88*$u), (164*$u), (88*$u)
    $bp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $br = 40 * $u
    $bp.AddArc($body.X, $body.Y, $br, $br, 180, 90)
    $bp.AddArc($body.Right - $br, $body.Y, $br, $br, 270, 90)
    $bp.AddArc($body.Right - $br, $body.Bottom - $br, $br, $br, 0, 90)
    $bp.AddArc($body.X, $body.Bottom - $br, $br, $br, 90, 90)
    $bp.CloseFigure()
    $g.DrawPath($pen, $bp)
    # strap
    $g.DrawLine($pen, (46*$u), (132*$u), (24*$u), (132*$u))
    $g.DrawLine($pen, (210*$u), (132*$u), (232*$u), (132*$u))
    # lenses: cyan + magenta glow
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $cyan), (74*$u), (108*$u), (48*$u), (48*$u))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $mag), (134*$u), (108*$u), (48*$u), (48*$u))

    # glitch slash splitting "flat vs VR"
    $slash = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, $yellow)), ([Math]::Max(1, 10*$u))
    $slash.StartCap = 'Round'; $slash.EndCap = 'Round'
    $g.DrawLine($slash, (176*$u), (40*$u), (80*$u), (216*$u))
    $g.Dispose()
    return $bmp
}

$sizes = 256, 128, 64, 48, 32, 16
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$pngs = foreach ($s in $sizes) {
    $b = Draw $s; $m = New-Object System.IO.MemoryStream
    $b.Save($m, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); ,$m.ToArray()
}
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $d = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$d); $bw.Write([byte]$d); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
[System.IO.File]::WriteAllBytes($out, $ms.ToArray())
# also a PNG preview
$prev = Draw 256; $prev.Save((Join-Path (Split-Path $out) 'cp2077-mode-preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
"wrote $out"
