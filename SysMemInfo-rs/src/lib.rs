//! SysMemInfo - exposes Windows memory status to scripts (redscript and CET Lua).
//!
//! Global functions, all returning Float megabytes:
//!   SysMem_AvailPhysMB()     free physical RAM
//!   SysMem_TotalPhysMB()     installed physical RAM (usable)
//!   SysMem_AvailCommitMB()   commit charge still available (RAM + page file)
//!   SysMem_CommitLimitMB()   commit limit (RAM + page file)
//!   SysMem_ProcessCommitMB() memory committed by the game process
//! CET: `Game.SysMem_AvailPhysMB()`

use red4ext_rs::{export_plugin_symbols, exports, global, wcstr, Exportable, GlobalExport, Plugin, SemVer, U16CStr};
use windows_sys::Win32::System::ProcessStatus::{GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS, PROCESS_MEMORY_COUNTERS_EX};
use windows_sys::Win32::System::SystemInformation::{GlobalMemoryStatusEx, MEMORYSTATUSEX};
use windows_sys::Win32::System::Threading::GetCurrentProcess;

const MB: f64 = 1024.0 * 1024.0;

pub struct SysMemInfo;

impl Plugin for SysMemInfo {
    const AUTHOR: &'static U16CStr = wcstr!("cyberpunk-mod-patches");
    const NAME: &'static U16CStr = wcstr!("SysMemInfo");
    const VERSION: SemVer = SemVer::new(1, 0, 0);

    fn exports() -> impl Exportable {
        exports![
            GlobalExport(global!(c"SysMem_AvailPhysMB", avail_phys_mb)),
            GlobalExport(global!(c"SysMem_TotalPhysMB", total_phys_mb)),
            GlobalExport(global!(c"SysMem_AvailCommitMB", avail_commit_mb)),
            GlobalExport(global!(c"SysMem_CommitLimitMB", commit_limit_mb)),
            GlobalExport(global!(c"SysMem_ProcessCommitMB", process_commit_mb)),
        ]
    }
}

export_plugin_symbols!(SysMemInfo);

fn status() -> Option<MEMORYSTATUSEX> {
    // SAFETY: MEMORYSTATUSEX is plain data; dwLength must be set before the call.
    let mut st: MEMORYSTATUSEX = unsafe { std::mem::zeroed() };
    st.dwLength = std::mem::size_of::<MEMORYSTATUSEX>() as u32;
    (unsafe { GlobalMemoryStatusEx(&mut st) } != 0).then_some(st)
}

fn mb(bytes: u64) -> f32 {
    (bytes as f64 / MB) as f32
}

fn avail_phys_mb() -> f32 {
    status().map_or(0.0, |s| mb(s.ullAvailPhys))
}

fn total_phys_mb() -> f32 {
    status().map_or(0.0, |s| mb(s.ullTotalPhys))
}

fn avail_commit_mb() -> f32 {
    status().map_or(0.0, |s| mb(s.ullAvailPageFile))
}

fn commit_limit_mb() -> f32 {
    status().map_or(0.0, |s| mb(s.ullTotalPageFile))
}

fn process_commit_mb() -> f32 {
    // SAFETY: counters is plain data with cb set; the EX struct starts with the base struct.
    let mut counters: PROCESS_MEMORY_COUNTERS_EX = unsafe { std::mem::zeroed() };
    counters.cb = std::mem::size_of::<PROCESS_MEMORY_COUNTERS_EX>() as u32;
    let ok = unsafe {
        GetProcessMemoryInfo(
            GetCurrentProcess(),
            &mut counters as *mut PROCESS_MEMORY_COUNTERS_EX as *mut PROCESS_MEMORY_COUNTERS,
            counters.cb,
        )
    };
    if ok != 0 { mb(counters.PrivateUsage as u64) } else { 0.0 }
}
