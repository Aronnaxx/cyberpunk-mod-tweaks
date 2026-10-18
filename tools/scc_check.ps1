# Offline redscript compile check of the deployed script set, optionally plus extra script folders
# (e.g. a patch that is not installed yet). Uses the game's engine\tools\scc.exe against a temp copy of
# r6\scripts + every red4ext plugin folder that contains .reds, and a copy of the vanilla final.redscripts.
# Usage: scc_check.ps1 [-Extra <folder with .reds>[,<folder>...]] [-Override <folder>[,<folder>...]]
# -Override puts each folder at r6\scripts\<folder name> (replacing a deployed copy of the same name), so a
# patch is compiled in the same place and order as in game. -Extra folders compile outside r6\scripts, which
# can hide name-resolution errors (FACC-HubButtonMove v1.1 passed as -Extra but failed in game).
# Output: error/warning counts and the error lines; exit code 1 on errors.
param([string[]]$Extra = @(), [string[]]$Override = @())
$game = 'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
$work = Join-Path $env:TEMP "claude\scc_check"
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$work\scripts", "$work\cache" | Out-Null
robocopy "$game\r6\scripts" "$work\scripts\r6" /E /NFL /NDL /NJH /NJS /NP | Out-Null
# Copy only the top-most folders that contain .reds (e.g. NewGamePlus\redscript, not also its subfolders):
# a parent copied with /E already includes its children, and copying both duplicates every type.
$dirs = Get-ChildItem "$game\red4ext\plugins" -Recurse -Filter *.reds | Select-Object -ExpandProperty DirectoryName -Unique | Sort-Object Length
$top = @(); foreach ($d in $dirs) { if (-not ($top | Where-Object { $d.StartsWith($_ + '\') })) { $top += $d } }
$top | ForEach-Object {
  $rel = $_.Substring("$game\red4ext\plugins".Length).TrimStart('\') -replace '[\\ ]', '_'
  robocopy $_ "$work\scripts\plugins\$rel" *.reds /E /NFL /NDL /NJH /NJS /NP | Out-Null
}
$i = 0
foreach ($x in $Extra) { $i++; robocopy $x "$work\scripts\extra$i" /E /NFL /NDL /NJH /NJS /NP | Out-Null }
foreach ($x in $Override) { robocopy $x "$work\scripts\r6\$(Split-Path $x -Leaf)" /MIR /NFL /NDL /NJH /NJS /NP | Out-Null }
Copy-Item "$game\r6\cache\final.redscripts" "$work\cache\final.redscripts"
# scc.exe shows a modal "Compilation error" box on failure and waits for OK. Run it hidden and close that
# box ourselves (WM_CLOSE = OK) so the check never interrupts the desktop.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class SccWin {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static void CloseErrorBoxes(uint pid) {
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid) {
        var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
        if (sb.ToString() == "Compilation error") { PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
      }
      return true;
    }, IntPtr.Zero);
  }
}
"@ -ErrorAction SilentlyContinue
$p = Start-Process "$game\engine\tools\scc.exe" -ArgumentList '-compile', "`"$work\scripts`"", '-customCacheDir', "`"$work\cache`"" `
  -WindowStyle Hidden -PassThru -RedirectStandardOutput "$work\out.txt" -RedirectStandardError "$work\err.txt"
while (-not $p.HasExited) { [SccWin]::CloseErrorBoxes([uint32]$p.Id); Start-Sleep -Milliseconds 100 }
$out = (Get-Content "$work\out.txt", "$work\err.txt" -Raw -ErrorAction SilentlyContinue) -join "`n"
$errs = ([regex]::Matches($out, '\[ERROR')).Count
$warns = ([regex]::Matches($out, '\[WARN')).Count
"errors=$errs warnings=$warns"
if ($errs) { ($out -split "`n" | Select-String -Pattern 'ERROR' -Context 0, 3 | ForEach-Object { $_.ToString() }) -join "`n"; exit 1 }
