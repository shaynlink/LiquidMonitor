import Foundation
import IOKit.ps

struct BatteryInfo {
    var level: Double // 0.0 to 1.0
    var isCharging: Bool
    var timeRemaining: Int // minutes, -1 if unknown
}

@MainActor
class BatteryMonitor: ObservableObject {
    @Published var batteryInfo: BatteryInfo = BatteryInfo(level: 0, isCharging: false, timeRemaining: -1)
    
    private var task: Task<Void, Never>?
    
    func startMonitoring() {
        updateBattery()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                updateBattery()
            }
        }
    }
    
    func stopMonitoring() {
        task?.cancel()
        task = nil
    }
    
    private func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let type = description[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    let currentCapacity = description[kIOPSCurrentCapacityKey] as? Double ?? 0
                    let maxCapacity = description[kIOPSMaxCapacityKey] as? Double ?? 100
                    let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                    let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int ?? -1
                    
                    let level = currentCapacity / maxCapacity
                    
                    self.batteryInfo = BatteryInfo(
                        level: level,
                        isCharging: isCharging,
                        timeRemaining: timeRemaining
                    )
                    return
                }
            }
        }
    }
}
