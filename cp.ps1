# Cyberpunk input helper: focus the game, send scan-code keys / relative mouse moves, take a half-size screenshot.
# Usage examples:
#   cp.ps1 -Shot
#   cp.ps1 -Key W -HoldMs 800 -Shot
#   cp.ps1 -MouseX 300 -Shot
#   cp.ps1 -Key F -Shot
param(
  [string]$Key = "",
  [int]$HoldMs = 80,
  [int]$MouseX = 0,
  [int]$MouseY = 0,
  [switch]$Click,
  [int]$AtX = -1,
  [int]$AtY = -1,
  [switch]$Shot,
  [int]$WaitMs = 400
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'CpInput2').Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CpInput2 {
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
  const uint KEY_SCANCODE = 0x0008, KEY_UP = 0x0002, KEY_EXT = 0x0001;
  public static void Key(ushort scan, bool up, bool ext) {
    var i = new INPUT[1]; i[0].type = 1;
    i[0].u.ki.wScan = scan; i[0].u.ki.dwFlags = KEY_SCANCODE | (up ? KEY_UP : 0) | (ext ? KEY_EXT : 0);
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Move(int dx, int dy) {
    var i = new INPUT[1]; i[0].type = 0; i[0].u.mi.dx = dx; i[0].u.mi.dy = dy; i[0].u.mi.dwFlags = 0x0001;
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Button(bool up) {
    var i = new INPUT[1]; i[0].type = 0; i[0].u.mi.dwFlags = up ? 0x0004u : 0x0002u;
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@
}

# set-1 scan codes (E = extended key)
$scan = @{
  W=0x11; A=0x1E; S=0x1F; D=0x20; E=0x12; F=0x21; R=0x13; Q=0x10; C=0x2E; V=0x2F; T=0x14; I=0x17; M=0x32; J=0x24; P=0x19; X=0x2D; Z=0x2C; H=0x23; G=0x22; K=0x25; L=0x26; B=0x30; N=0x31; Y=0x15; U=0x16; O=0x18;
  "1"=0x02; "2"=0x03; "3"=0x04; "4"=0x05; SPACE=0x39; SHIFT=0x2A; CTRL=0x1D; ALT=0x38; TAB=0x0F; ESC=0x01; ENTER=0x1C; BACK=0x0E;
  F1=0x3B; F2=0x3C; F3=0x3D; F4=0x3E; F5=0x3F; F9=0x43; TILDE=0x29;
  HOME=0xE047; END=0xE04F; UP=0xE048; DOWN=0xE050; LEFT=0xE04B; RIGHT=0xE04D
}

$p = Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { "game not running"; exit 1 }
$h = $p.MainWindowHandle
if ([CpInput2]::GetForegroundWindow() -ne $h) {
  [CpInput2]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [CpInput2]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)   # alt tap unlocks SetForegroundWindow
  [CpInput2]::SetForegroundWindow($h) | Out-Null
  Start-Sleep -Milliseconds 600
}
$focused = ([CpInput2]::GetForegroundWindow() -eq $h)
if (-not $focused -and ($Key -ne "" -or $MouseX -ne 0 -or $MouseY -ne 0 -or $Click -or $AtX -ge 0)) { "NOT FOCUSED - no input sent"; exit 2 }

if ($MouseX -ne 0 -or $MouseY -ne 0) {
  # move in small steps so the game reads it as a smooth turn
  $steps = 20
  for ($i = 0; $i -lt $steps; $i++) { [CpInput2]::Move([int]($MouseX / $steps), [int]($MouseY / $steps)); Start-Sleep -Milliseconds 10 }
}
if ($AtX -ge 0) { [CpInput2]::SetCursorPos($AtX, $AtY) | Out-Null; Start-Sleep -Milliseconds 120 }
if ($Click) { [CpInput2]::Button($false); Start-Sleep -Milliseconds 60; [CpInput2]::Button($true) }
if ($Key -ne "") {
  foreach ($k in $Key.Split('+')) {
    $code = [int]$scan[$k.ToUpper()]
    if (-not $code) { "unknown key $k"; exit 1 }
  }
  $keys = $Key.Split('+') | ForEach-Object { [int]$scan[$_.ToUpper()] }
  foreach ($c in $keys) { [CpInput2]::Key([uint16]($c -band 0xFF), $false, ($c -gt 0xFF)) }
  Start-Sleep -Milliseconds $HoldMs
  [array]::Reverse($keys)
  foreach ($c in $keys) { [CpInput2]::Key([uint16]($c -band 0xFF), $true, ($c -gt 0xFF)) }
}
Start-Sleep -Milliseconds $WaitMs

if ($Shot) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $small = New-Object System.Drawing.Bitmap $bmp, ([int]($b.Width / 2)), ([int]($b.Height / 2))
  $out = "$env:TEMP\claude\cp_shot.png"
  $small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); $small.Dispose()
}
"focused=$focused key=$Key mouse=$MouseX,$MouseY"
