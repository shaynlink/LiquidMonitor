import AppKit
import Foundation
import SwiftUI

struct RunningProcessInfo: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let bundleIdentifier: String?
    
    // Extended stats (Placeholders for now, to be implemented via sysctl/libproc)
    var user: String = NSUserName()
    var threadCount: Int = 0
    var idleWakeUps: Int = 0
    var cpuUsage: Double = 0.0
}

@MainActor
class ProcessProvider: ObservableObject {
    @Published var processes: [RunningProcessInfo] = []
    
    private var task: Task<Void, Never>?
    
    func startMonitoring() {
        refreshProcesses()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                refreshProcesses()
            }
        }
    }
    
    func stopMonitoring() {
        task?.cancel()
        task = nil
    }
    
    private func refreshProcesses() {
        let apps = NSWorkspace.shared.runningApplications
        
        // Fetch extended info for all processes in one go
        let extendedInfo = fetchProcessExtendedInfo()
        
        let processList = apps.filter { $0.activationPolicy == .regular }.map { app in
            let pid = app.processIdentifier
            let info = extendedInfo[pid]
            
            return RunningProcessInfo(
                id: pid,
                name: app.localizedName ?? "Unknown",
                icon: app.icon,
                bundleIdentifier: app.bundleIdentifier,
                user: info?.user ?? NSUserName(),
                threadCount: 0, // Not available in basic ps -o
                idleWakeUps: 0,
                cpuUsage: info?.cpu ?? 0.0
            )
        }.sorted { $0.name < $1.name }
        
        self.processes = processList
        
        // Real-time history (no buffer)
        addToHistory(from: processList)
    }
    
    // History
    struct AppSnapshot: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let apps: [AppUsage]
        
        struct AppUsage: Identifiable, Equatable {
            var id: String { name }
            let name: String
            let value: Double
            let color: Color
            
            static func == (lhs: AppUsage, rhs: AppUsage) -> Bool {
                return lhs.name == rhs.name && lhs.value == rhs.value
            }
        }
    }
    
    @Published var history: [AppSnapshot] = []
    private var buffer: [[RunningProcessInfo]] = []
    
    private struct RawProcessInfo {
        let user: String
        let cpu: Double
    }
    
    // Parses output of: ps -A -o pid=,user=,%cpu=
    private func fetchProcessExtendedInfo() -> [pid_t: RawProcessInfo] {
        let task = Process()
        task.launchPath = "/bin/ps"
        // -A: all processes
        // -o: output format (pid, user, %cpu)
        // the '=' sign suppresses the header row
        task.arguments = ["-A", "-o", "pid=,user=,%cpu="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var results: [pid_t: RawProcessInfo] = [:]
                
                output.enumerateLines { line, _ in
                    // Format: " PID USER %CPU" (variable whitespace)
                    let components = line.split(separator: " ", omittingEmptySubsequences: true)
                    if components.count >= 3,
                       let pid = pid_t(components[0]),
                       let cpu = Double(components[2]) {
                        
                        let user = String(components[1])
                        results[pid] = RawProcessInfo(user: user, cpu: cpu)
                    }
                }
                return results
            }
        } catch {
            print("Failed to fetch ps info: \(error)")
        }
        return [:]
    }

    private func scaleDownOldHistory() {
        if history.count > 20 {
             history.removeFirst(history.count - 20)
        }
    }

    private func addToHistory(from apps: [RunningProcessInfo]) {
        // Sort by CPU
        let sorted = apps.sorted { $0.cpuUsage > $1.cpuUsage }
        
        // Take Top 5
        var finalUsage: [AppSnapshot.AppUsage] = []
        let top5 = sorted.prefix(5)
        
        for app in top5 {
            finalUsage.append(AppSnapshot.AppUsage(
                name: app.name,
                value: app.cpuUsage,
                color: Color.distinct(seed: app.name)
            ))
        }
        
        // Others
        if sorted.count > 5 {
             let othersTotal = sorted.dropFirst(5).reduce(0) { $0 + $1.cpuUsage }
             if othersTotal > 0.1 {
                 finalUsage.append(AppSnapshot.AppUsage(
                    name: "Others",
                    value: othersTotal,
                    color: .gray
                 ))
             }
        }
        
        // Append
        let snapshot = AppSnapshot(timestamp: Date(), apps: finalUsage)
        history.append(snapshot)
        scaleDownOldHistory()
    }
}
