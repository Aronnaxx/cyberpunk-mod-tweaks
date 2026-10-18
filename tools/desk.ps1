# Desktop input helper (generalised cp.ps1): focus a window by process name, send clicks / keys / text,
# and take a half-size screenshot. Coordinates are full-resolution screen pixels.
# Usage examples:
#   desk.ps1 -Proc Vortex -Shot
#   desk.ps1 -Proc Vortex -AtX 640 -AtY 300 -Click -Shot
#   desk.ps1 -Proc Vortex -Type "Equipment Bonus" -Shot
#   desk.ps1 -Proc Vortex -Key CTRL+A
#   desk.ps1 -Proc Cyberpunk2077 -Key I -Shot
param(
  [string]$Proc = "Cyberpunk2077",
  [string]$Key = "",
  [int]$HoldMs = 80,
  [string]$Type = "",
  [int]$AtX = -1,
  [int]$AtY = -1,
  [switch]$Click,
  [switch]$DoubleClick,
  [switch]$RightClick,
  [int]$Wheel = 0,
  [switch]$Shot,
  [string]$ShotName = "desk_shot",
  [int]$WaitMs = 400,
  [switch]$NoFocus,
  [switch]$Rel   # AtX/AtY are relative to the target window's top-left corner
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'DeskInput').Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DeskInput {
  [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }
  [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  static void Send(INPUT i) { SendInput(1, new INPUT[] { i }, Marshal.SizeOf(typeof(INPUT))); }
  public static void Key(ushort scan, bool up, bool ext) {
    var i = new INPUT(); i.type = 1;
    i.u.ki.wScan = scan; i.u.ki.dwFlags = 0x0008u | (up ? 0x0002u : 0u) | (ext ? 0x0001u : 0u);
    Send(i);
  }
  public static void Char(char c) {
    foreach (bool up in new[] { false, true }) {
      var i = new INPUT(); i.type = 1; i.u.ki.wScan = c; i.u.ki.dwFlags = 0x0004u | (up ? 0x0002u : 0u);
      Send(i);
    }
  }
  public static void Button(uint down, uint up) {
    var i = new INPUT(); i.type = 0; i.u.mi.dwFlags = down; Send(i);
    System.Threading.Thread.Sleep(50);
    var j = new INPUT(); j.type = 0; j.u.mi.dwFlags = up; Send(j);
  }
  public static void Wheel(int clicks) {
    var i = new INPUT(); i.type = 0; i.u.mi.dwFlags = 0x0800; i.u.mi.mouseData = (uint)(clicks * 120); Send(i);
  }
}
"@
}

# set-1 scan codes (values > 0xFF are extended keys)
$scan = @{
  W=0x11; A=0x1E; S=0x1F; D=0x20; E=0x12; F=0x21; R=0x13; Q=0x10; C=0x2E; V=0x2F; T=0x14; I=0x17; M=0x32; J=0x24; P=0x19; X=0x2D; Z=0x2C; H=0x23; G=0x22; K=0x25; L=0x26; B=0x30; N=0x31; Y=0x15; U=0x16; O=0x18;
  "1"=0x02; "2"=0x03; "3"=0x04; "4"=0x05; SPACE=0x39; SHIFT=0x2A; CTRL=0x1D; ALT=0x38; TAB=0x0F; ESC=0x01; ENTER=0x1C; BACK=0x0E; DEL=0xE053;
  F1=0x3B; F2=0x3C; F3=0x3D; F4=0x3E; F5=0x3F; F9=0x43; TILDE=0x29;
  HOME=0xE047; END=0xE04F; UP=0xE048; DOWN=0xE050; LEFT=0xE04B; RIGHT=0xE04D; PGUP=0xE049; PGDN=0xE051
}

$focused = $true
if (-not $NoFocus) {
  $p = Get-Process $Proc -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { "window for $Proc not found"; exit 1 }
  $h = $p.MainWindowHandle
  if ([DeskInput]::GetForegroundWindow() -ne $h) {
    [DeskInput]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [DeskInput]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [DeskInput]::ShowWindow($h, 9) | Out-Null
    [DeskInput]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 600
  }
  $focused = ([DeskInput]::GetForegroundWindow() -eq $h)
  $acts = ($Key -ne "" -or $Type -ne "" -or $Click -or $DoubleClick -or $RightClick -or $Wheel -ne 0)
  if (-not $focused -and $acts) { "NOT FOCUSED - no input sent"; exit 2 }
}

if ($Rel -and $AtX -ge 0) {
  $r = New-Object DeskInput+RECT
  [DeskInput]::GetWindowRect($h, [ref]$r) | Out-Null
  $AtX += $r.Left; $AtY += $r.Top
}
if ($AtX -ge 0) { [DeskInput]::SetCursorPos($AtX, $AtY) | Out-Null; Start-Sleep -Milliseconds 150 }
if ($Click) { [DeskInput]::Button(0x0002, 0x0004) }
if ($DoubleClick) { [DeskInput]::Button(0x0002, 0x0004); Start-Sleep -Milliseconds 80; [DeskInput]::Button(0x0002, 0x0004) }
if ($RightClick) { [DeskInput]::Button(0x0008, 0x0010) }
if ($Wheel -ne 0) { [DeskInput]::Wheel($Wheel) }
if ($Type -ne "") { foreach ($ch in $Type.ToCharArray()) { [DeskInput]::Char($ch); Start-Sleep -Milliseconds 15 } }
if ($Key -ne "") {
  $keys = @()
  foreach ($k in $Key.Split('+')) {
    $code = $scan[$k.ToUpper()]
    if (-not $code) { "unknown key $k"; exit 1 }
    $keys += [int]$code
  }
  foreach ($c in $keys) { [DeskInput]::Key([uint16]($c -band 0xFF), $false, ($c -gt 0xFF)) }
  Start-Sleep -Milliseconds $HoldMs
  [array]::Reverse($keys)
  foreach ($c in $keys) { [DeskInput]::Key([uint16]($c -band 0xFF), $true, ($c -gt 0xFF)) }
}
Start-Sleep -Milliseconds $WaitMs

if ($Shot) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $small = New-Object System.Drawing.Bitmap $bmp, ([int]($b.Width / 2)), ([int]($b.Height / 2))
  $dir = "$env:TEMP\claude"; New-Item -ItemType Directory -Force $dir | Out-Null
  $out = "$dir\$ShotName.png"
  $small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); $small.Dispose()
  "shot=$out screen=$($b.Width)x$($b.Height) (image is half size: multiply image coords by 2)"
}
"focused=$focused"
