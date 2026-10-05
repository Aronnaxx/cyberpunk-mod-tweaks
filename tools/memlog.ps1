# Logs system and Cyberpunk memory every $Every seconds to a CSV until the game exits.
# Columns match what zz_LuaGCTuner/SysMemInfo reads (GlobalMemoryStatusEx) plus what
# Task Manager shows for the game process.
param([int]$Every = 5, [string]$Out = "$PSScriptRoot\..\memlog-$(Get-Date -f yyyyMMdd-HHmm).csv")

Add-Type @"
using System; using System.Runtime.InteropServices;
public static class MemStat {
  [StructLayout(LayoutKind.Sequential)] public class MS {
    public uint dwLength = (uint)Marshal.SizeOf(typeof(MS)); public uint dwMemoryLoad;
    public ulong TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual, AvailExtendedVirtual; }
  [DllImport("kernel32.dll")] public static extern bool GlobalMemoryStatusEx([In, Out] MS b);
}
"@

$mb = 1MB
"time,availPhysMB,ramInUseMB,availCommitMB,commitUsedMB,commitLimitMB,gameWorkingSetMB,gamePrivateWsMB,gameCommitMB,gamePeakWsMB" | Set-Content -Encoding utf8 $Out
$seen = $false
while ($true) {
  $p = Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p) { $seen = $true } elseif ($seen) { break }
  $s = New-Object MemStat+MS; [void][MemStat]::GlobalMemoryStatusEx($s)
  $pws = ""
  if ($p) {
    try { $pws = [math]::Round((Get-Counter "\Process(Cyberpunk2077)\Working Set - Private" -ErrorAction Stop).CounterSamples[0].CookedValue / $mb) } catch {}
  }
  $row = @(
    (Get-Date -f "HH:mm:ss"),
    [math]::Round($s.AvailPhys / $mb), [math]::Round(($s.TotalPhys - $s.AvailPhys) / $mb),
    [math]::Round($s.AvailPageFile / $mb), [math]::Round(($s.TotalPageFile - $s.AvailPageFile) / $mb),
    [math]::Round($s.TotalPageFile / $mb),
    $(if ($p) { [math]::Round($p.WorkingSet64 / $mb) } else { "" }), $pws,
    $(if ($p) { [math]::Round($p.PrivateMemorySize64 / $mb) } else { "" }),
    $(if ($p) { [math]::Round($p.PeakWorkingSet64 / $mb) } else { "" })
  ) -join ","
  Add-Content -Encoding utf8 $Out $row
  Start-Sleep -Seconds $Every
}
