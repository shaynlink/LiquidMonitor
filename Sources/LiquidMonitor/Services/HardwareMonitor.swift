import Foundation
import Darwin
import IOKit
import IOKit.ps

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
    
    // Root & Advanced
    let rootService = RootService()
    // parser is now local struct
    @Published var isRootMode: Bool = false
    @Published var cpuFrequencyPCore: Double = 0.0 // GHz
    @Published var cpuFrequencyECore: Double = 0.0 // GHz
    @Published var cpuFrequencyClusters: [String: Double] = [:] // Dynamic map for all clusters (P0, P1, E, etc.)
    @Published var packagePower: Double = 0.0 // Watts
    
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
        
        startBatteryMonitoring()
        
        // Observe Root Service
        Task { @MainActor in
            for await granted in rootService.$isRootGranted.values {
                self.isRootMode = granted
            }
        }
    }
    
    // Extended Metrics
    @Published var cpuBrand: String = "Unknown CPU"
    @Published var uptime: TimeInterval = 0
    @Published var loadAverage: [Double] = [0, 0, 0]
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    // Missing properties restoration
    @Published var loadAverageHistory: [[Double]] = []
    @Published var gpuUsage: Double = 0.0
    
    // Phase 1: Real-time Stats
    // Phase 1: Real-time Stats
    @Published var processCount: Int = 0
    @Published var contextSwitchesRate: Int = 0
    @Published var contextSwitchesTotal: Int = 0
    
    // Internal state for stats calculation
    
    // Total CPU for Sparkline
    @Published var cpuUsageTotal: Double = 0.0
    // Total GPU for Sparkline
    @Published var gpuHistory: [Double] = Array(repeating: 0, count: 60)
    
    private var lastCSWTotal: Int = 0
    
    // Phase 2: Static Info
    @Published var l1ICacheSize: Int = 0
    @Published var l1DCacheSize: Int = 0
    @Published var l2CacheSize: Int = 0
    @Published var cpuFeatures: [String] = []
    
    // Phase 4: Experimental
    @Published var batteryCurrent: Int = 0 // mA
    
    // Helper to calculate total CPU usage % from global ticks
    // We need to store previous ticks to calc diff
    private var lastUser: UInt32 = 0
    private var lastSystem: UInt32 = 0
    private var lastIdle: UInt32 = 0
    private var lastNice: UInt32 = 0
    
    func startMonitoring() {
        // Fetch static info once
        self.cpuBrand = getCPUBrand()
        self.l1ICacheSize = getSysctlInt("hw.l1icachesize")
        self.l1DCacheSize = getSysctlInt("hw.l1dcachesize")
        self.l2CacheSize = getSysctlInt("hw.l2cachesize")
        // CPU features can be extensive, we'll implement a helper to select key ones
        self.cpuFeatures = getCPUFeatures()
        
        task = Task {
            while !Task.isCancelled {
                updateStats()
                // Update slightly less frequently for heavy operations if needed
                self.processCount = getProcessCount()
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            }
        }
    }
    
    // Battery Monitoring

    private var batteryTimer: Timer?
    
    private func startBatteryMonitoring() {
        // Initial update
        self.batteryCurrent = getBatteryAmperage()
        
        // Schedule 10s timer
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.batteryCurrent = self?.getBatteryAmperage() ?? 0
            }
        }
    }
    
    private func getBatteryAmperage() -> Int {
        // Simple IOKit Check first (IOPS doesn't always give instant amperage easily)
        // Let's use specific IORegistry lookup for AppleSmartBattery as verified in research
        
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer { IOObjectRelease(service) }
        
        if service != 0 {
            if let prop = IORegistryEntryCreateCFProperty(service, "InstantAmperage" as CFString, kCFAllocatorDefault, 0) {
                let value = prop.takeRetainedValue() as? Int ?? 0
                return value
            }
        }
        
        return 0
    }
    
    // Neural Engine Monitoring
    @Published var isNeuralEngineActive: Bool = false
    
    private func checkNeuralEngineStatus() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("H11ANEIn"))
        defer { IOObjectRelease(service) }
        
        if service != 0 {
            if let prop = IORegistryEntryCreateCFProperty(service, "IOPowerManagement" as CFString, kCFAllocatorDefault, 0),
               let dict = prop.takeRetainedValue() as? [String: Any],
               let state = dict["CurrentPowerState"] as? Int {
                return state > 0
            }
        }
        return false
    }
    
    func stopMonitoring() {
        task?.cancel()
        batteryTimer?.invalidate()
        task = nil
    }
    
    private func updateStats() {
        let cpu = getCPUUsage()
        let ram = getRAMUsage()
        
        self.stats.cpuUsage = cpu
        self.stats.ramUsage = ram
        
        // Update History
        self.cpuHistory.removeFirst()
        self.cpuHistory.append(cpu)
        
        // Update Extended Metrics
        self.uptime = ProcessInfo.processInfo.systemUptime
        self.thermalState = ProcessInfo.processInfo.thermalState
        self.loadAverage = getLoadAverage()
        self.loadAverageHistory.append(self.loadAverage)
        if self.loadAverageHistory.count > 60 { self.loadAverageHistory.removeFirst() }
        
        // Update CPU Total & History
        let newUsage = calculateTotalCPUUsage()
        self.cpuUsageTotal = newUsage
        self.cpuHistory.append(newUsage)
        if self.cpuHistory.count > 60 { self.cpuHistory.removeFirst() }
        
        // Update CSW Rate
        let currentCSW = getContextSwitches()
        if lastCSWTotal > 0 {
            self.contextSwitchesRate = currentCSW - lastCSWTotal
        }
        self.contextSwitchesTotal = currentCSW
        self.lastCSWTotal = currentCSW
        
        self.gpuUsage = getGPUUsage()
        self.gpuHistory.append(self.gpuUsage)
        if self.gpuHistory.count > 60 { self.gpuHistory.removeFirst() }
        
        self.batteryCurrent = getBatteryAmperage()
        
        self.isNeuralEngineActive = checkNeuralEngineStatus()
        
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
        
        if isRootMode {
            // Capture values from MainActor before detaching
            let path = self.rootService.getMetricsPath()
            
            Task.detached(priority: .background) {
                // Read file as Data
                // powermetrics -f plist outputs multiple XML documents concatenated
                // We must find the last one to get the latest sample.
                let url = URL(fileURLWithPath: path)
                do {
                    // TODO: For very large files, this is inefficient. We should seek to the end.
                    // For now, assuming file is reset on app launch or reasonable size
                    let data = try Data(contentsOf: url)
                    if data.isEmpty { return }
                    
                    guard let fullContent = String(data: data, encoding: .utf8) else { return }
                    
                    // Split by XML declaration
                    let distinctSamples = fullContent.components(separatedBy: "<?xml")
                    
                    // The first component might be empty if file starts with <?xml
                    // We want the last non-empty one that contains </plist>
                    if let lastValidSample = distinctSamples.reversed().first(where: { $0.contains("</plist>") }) {
                        // Re-add the header which was removed by splitting
                        let parseableContent = "<?xml" + lastValidSample
                        
                        let parser = PowermetricsParser()
                        if let sample = parser.parse(content: parseableContent) {
                             await MainActor.run {
                                 // Update Power Metrics
                                 if let cpuW = sample.cpu_power { self.packagePower = cpuW / 1000.0 }
                                 
                                 let clusters = sample.processor?.clusters ?? sample.processor?.packages?.first?.clusters
                                 
                                 if let clusters = clusters {
                                     for cluster in clusters {
                                         let hz = cluster.freq_hz ?? 0
                                         let ghz = hz / 1_000_000_000.0
                                         let name = cluster.name ?? "Unknown"
                                         
                                         // Update dynamic map
                                         self.cpuFrequencyClusters[name] = ghz
                                         
                                         // Update legacy fields
                                         if name.contains("E-Cluster") {
                                             self.cpuFrequencyECore = ghz
                                         } else if name.hasPrefix("P") && name.hasSuffix("-Cluster") {
                                             if self.cpuFrequencyPCore < ghz {
                                                 self.cpuFrequencyPCore = ghz
                                             }
                                         }
                                     }
                                 }
                             }
                        }
                    }
                } catch {
                     // Ignore read errors
                }
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
    
    // MARK: - Helper Methods
    
    private func getCPUBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        // Convert CChar array to UInt8 array for decoding
        let data = brand.map { UInt8(bitPattern: $0) }
        // Drop null terminators for cleaner string
        return String(decoding: data.filter { $0 != 0 }, as: UTF8.self)
    }
    private func getLoadAverage() -> [Double] {
        var loadAvgs = [Double](repeating: 0.0, count: 3)
        getloadavg(&loadAvgs, 3)
        return loadAvgs
    }
    
    private func getProcessCount() -> Int {
        // Get buffer size needed
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        let count = bufferSize / Int32(MemoryLayout<pid_t>.size)
        return Int(count)
    }
    
    // MARK: - Phase 1 Helpers (GPU)
    
    private func getGPUUsage() -> Double {
        var iterator = io_iterator_t()
        let match = IOServiceMatching("IOAccelerator")
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == kIOReturnSuccess else {
            return 0.0
        }
        
        var totalUsage = 0.0
        var found = false
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let properties = props?.takeRetainedValue() as? [String: Any] {
                
                if let stats = properties["PerformanceStatistics"] as? [String: Any] {
                     // Try known keys for Apple Silicon
                    if let util = stats["Device Utilization %"] as? Int {
                        totalUsage = Double(util)
                        found = true
                    } else if let util = stats["GPU utilisation %"] as? Int {
                         totalUsage = Double(util)
                         found = true
                    }
                }
            }
            IOObjectRelease(service)
            if found { break } // Assume main GPU is first relevant one found
        }
        
        IOObjectRelease(iterator)
        return totalUsage
    }
    
    // MARK: - Phase 4 Helpers (Experimental)
    
    // Returns current in mA (negative = discharging, positive = charging)
    private func getBatteryCurrent() -> Int {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return 0
        }
        
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] {
                if let current = info[kIOPSCurrentKey] as? Int {
                    return current
                }
            }
        }
        
        return 0
    }
    
    // MARK: - Phase 1 Completers (Context Switches)
    
    // Structure mirroring proc_taskinfo from bsd/sys/proc_info.h
    private struct proc_taskinfo {
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
        var pti_csw: Int32 = 0
        var pti_threadnum: Int32 = 0
        var pti_numrunning: Int32 = 0
        var pti_priority: Int32 = 0
    }
    
    private func getContextSwitches() -> Int {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        let count = bufferSize / Int32(MemoryLayout<pid_t>.size)
        // Check reasonable count to avoid massive allocation attacks or errors
        guard count > 0 && count < 100_000 else { return 0 }
        
        var pids = [pid_t](repeating: 0, count: Int(count))
        _ = pids.withUnsafeMutableBufferPointer {
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, bufferSize)
        }
        
        var totalCSW = 0
        let procTaskInfoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        let type = Int32(PROC_PIDTASKINFO)
        
        for pid in pids {
            // proc_pidinfo returns the amount of data written, checking if it equals expected struct size
             var info = proc_taskinfo()
             if proc_pidinfo(pid, type, 0, &info, procTaskInfoSize) == procTaskInfoSize {
                 totalCSW += Int(info.pti_csw)
             }
        }
        
        return totalCSW
    }
    

    
    private func calculateTotalCPUUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var cpuStats = host_cpu_load_info_data_t()
        
        let result = withUnsafeMutablePointer(to: &cpuStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let user = cpuStats.cpu_ticks.0
        let system = cpuStats.cpu_ticks.1
        let idle = cpuStats.cpu_ticks.2
        let nice = cpuStats.cpu_ticks.3
        
        let deltaUser = Double(user - lastUser)
        let deltaSystem = Double(system - lastSystem)
        let deltaIdle = Double(idle - lastIdle)
        let deltaNice = Double(nice - lastNice)
        
        let total = deltaUser + deltaSystem + deltaIdle + deltaNice
        
        // Update last values
        lastUser = user
        lastSystem = system
        lastIdle = idle
        lastNice = nice
        
        if total > 0 {
            return ((deltaUser + deltaSystem + deltaNice) / total) * 100.0
        }
        return 0.0
    }
    
    // MARK: - Phase 2 Helpers
    
    private func getSysctlInt(_ name: String) -> Int {
        var size = MemoryLayout<Int>.size
        var value = 0
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
    
    private func getCPUFeatures() -> [String] {
        var features: [String] = []
        // Check for common Apple Silicon features via hw.optional
        let keys = ["hw.optional.arm64", "hw.optional.neon", "hw.optional.floatingpoint", "hw.optional.neon_hpfp", "hw.optional.neon_fp16"]
        
        for key in keys {
            if getSysctlInt(key) == 1 {
                features.append(key.replacingOccurrences(of: "hw.optional.", with: "").uppercased())
            }
        }
        
        // Manual additions for Apple Silicon if detection is generic
        if self.cpuBrand.contains("Apple") {
            if !features.contains("NEON") { features.append("NEON") }
            features.append("AMX") // Apple Matrix Coprocessor
        }
        
        return features
    }
}
