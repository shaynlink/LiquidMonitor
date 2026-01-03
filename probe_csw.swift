import Foundation
import Darwin

// Define missing structures/constants for Swift
let PROC_ALL_PIDS: UInt32 = 1
let PROC_PIDTASKINFO: Int32 = 4

// We need to mirror proc_taskinfo struct
struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0           // We want this!
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

func getPids() -> [pid_t] {
    let bufferSize = proc_listpids(PROC_ALL_PIDS, 0, nil, 0)
    let count = Int(bufferSize) / MemoryLayout<pid_t>.size
    var pids = [pid_t](repeating: 0, count: count)
    _ = pids.withUnsafeMutableBufferPointer {
        proc_listpids(PROC_ALL_PIDS, 0, $0.baseAddress, bufferSize)
    }
    return pids
}

func getTotalContextSwitches() -> Int {
    let pids = getPids()
    var totalCSW = 0
    
    for pid in pids {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        
        if result == size {
            totalCSW += Int(info.pti_csw)
        }
    }
    return totalCSW
}

print("Starting measurement...")
let start = Date()
let csw = getTotalContextSwitches()
let elapsed = Date().timeIntervalSince(start)

print("Total Context Switches: \(csw)")
print("Time elapsed: \(String(format: "%.4f", elapsed))s")
print("Estimated CPU usage cost: Low to Moderate")
