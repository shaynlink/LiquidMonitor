import Foundation
import Darwin

@MainActor
class HardwareMonitor: ObservableObject {
    @Published var stats: SystemStats = SystemStats(cpuUsage: 0, ramUsage: 0, totalRam: 0)
    // Global CPU history
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    // Per-core history: [CoreIndex: [UsageHistory]]
    @Published var perCoreHistory: [[Double]] = []
    
    private var task: Task<Void, Never>?
    private let pageSize = Double(sysconf(_SC_PAGESIZE))
    
    // Core counts
    @Published var performanceCoreCount: Int = 0
    @Published var efficiencyCoreCount: Int = 0
    
    // Per-core tracking
    private var previousCoreLoad: processor_cpu_load_info_data_t? 
    private var previousCoreTicks: [processor_cpu_load_info] = []
    
    init() {
        // Initialize total RAM
        let totalRam = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024 // GB
        stats.totalRam = totalRam
        
        // Detect Core Types (Simple sysctl approach for Apple Silicon)
        // Usually E-cores are level 1, P-cores are level 0 on macOS ARM, but ordering in processor_info varies.
        // Common observation on M-series: E-cores are 0..<nE, P-cores are nE..<Total.
        // Let's fetch counts.
        
        var size = MemoryLayout<Int>.size
        var perfCount = 0
        var effCount = 0
        
        // Try to read hw.perflevel0.logicalcpu (Performance)
        sysctlbyname("hw.perflevel0.logicalcpu", &perfCount, &size, nil, 0)
        
        // Try to read hw.perflevel1.logicalcpu (Efficiency)
        sysctlbyname("hw.perflevel1.logicalcpu", &effCount, &size, nil, 0)
        
        // If detection fails or is x86 (no perflevels usually), fallback
        let totalCores = ProcessInfo.processInfo.processorCount
        
        if perfCount > 0 && effCount > 0 && (perfCount + effCount == totalCores) {
            self.performanceCoreCount = perfCount
            self.efficiencyCoreCount = effCount
        } else {
            // Fallback: Assume all are performance or split evenly? 
            // Better to show all as "Cores" if unknown.
            self.performanceCoreCount = totalCores
            self.efficiencyCoreCount = 0
        }
    }
    
    func startMonitoring() {
        task = Task {
            while !Task.isCancelled {
                updateStats()
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            }
        }
    }
    
    func stopMonitoring() {
        task?.cancel()
        task = nil
    }
    
    private func updateStats() {
        let cpu = getCPUUsage()
        let ram = getRAMUsage()
        
        self.stats.cpuUsage = cpu
        self.stats.ramUsage = ram
        
        // Update Global History
        self.cpuHistory.removeFirst()
        self.cpuHistory.append(cpu)
        
        // Update Per-Core History
        let coreUsages = getPerCoreUsage()
        if self.perCoreHistory.isEmpty && !coreUsages.isEmpty {
            // Initialize history buffers for each core
            self.perCoreHistory = coreUsages.map { _ in Array(repeating: 0.0, count: 60) }
        }
        
        if coreUsages.count == self.perCoreHistory.count {
            for (index, usage) in coreUsages.enumerated() {
                self.perCoreHistory[index].removeFirst()
                self.perCoreHistory[index].append(usage)
            }
        }
    }
    
    private var loadPrevious = host_cpu_load_info()
    
    private func getCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userDiff = Double(cpuLoad.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
            let sysDiff  = Double(cpuLoad.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
            let idleDiff = Double(cpuLoad.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
            let niceDiff = Double(cpuLoad.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
            
            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
            let usedTicks  = userDiff + sysDiff + niceDiff
            
            loadPrevious = cpuLoad
            
            if totalTicks > 0 {
                return (usedTicks / totalTicks) * 100.0
            }
        }
        
        return 0.0
    }
    
    private func getPerCoreUsage() -> [Double] {
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorInfo: processor_info_array_t?
        var processorCount = mach_msg_type_number_t(0)
        
        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &processorCount,
                                         &processorInfo,
                                         &processorMsgCount)
                                         
        guard result == KERN_SUCCESS, let info = processorInfo else {
            return []
        }
        
        var usages: [Double] = []
        
        // Initialize previous ticks if needed
        if previousCoreTicks.count != Int(processorCount) {
             previousCoreTicks = Array(repeating: processor_cpu_load_info(), count: Int(processorCount))
        }
        
        // Iterate through cores
        // processorInfo is an array of integer_t (int32).
        // Each core has CPU_STATE_MAX (4) ticks: User, System, Idle, Nice.
        // So step is 4.
        
        let step = Int(CPU_STATE_MAX)
        for i in 0..<Int(processorCount) {
            let base = i * step
            
            // Access raw data safely
            // Note: processorInfo is a pointer to integer_t
            
            let user = info[base + Int(CPU_STATE_USER)]
            let system = info[base + Int(CPU_STATE_SYSTEM)]
            let idle = info[base + Int(CPU_STATE_IDLE)]
            let nice = info[base + Int(CPU_STATE_NICE)]
            
            let currentTicks = processor_cpu_load_info(cpu_ticks: (
                UInt32(user), UInt32(system), UInt32(idle), UInt32(nice)
            ))
            
            let prevTicks = previousCoreTicks[i]
            
            let userDiff = Double(currentTicks.cpu_ticks.0 - prevTicks.cpu_ticks.0)
            let sysDiff  = Double(currentTicks.cpu_ticks.1 - prevTicks.cpu_ticks.1)
            let idleDiff = Double(currentTicks.cpu_ticks.2 - prevTicks.cpu_ticks.2)
            let niceDiff = Double(currentTicks.cpu_ticks.3 - prevTicks.cpu_ticks.3)
            
            let total = userDiff + sysDiff + idleDiff + niceDiff
            let used = userDiff + sysDiff + niceDiff
            
            let usage = total > 0 ? (used / total) * 100.0 : 0.0
            usages.append(usage)
            
            previousCoreTicks[i] = currentTicks
        }
        
        // Deallocate
        let infoSize = Int(processorMsgCount) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoSize))
        
        return usages
    }
    
    private func getRAMUsage() -> Double {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let active = Double(stats.active_count) * pageSize
            let wire = Double(stats.wire_count) * pageSize
            // Approximate "Used" memory
            let used = (active + wire) / 1024 / 1024 / 1024 // GB
            return used
        }
        
        return 0
    }
}
