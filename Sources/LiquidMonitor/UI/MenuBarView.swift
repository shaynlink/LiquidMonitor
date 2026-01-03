import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var hardwareMonitor: HardwareMonitor
    // Remove openWindow as we use manual window management now
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CPU: \(String(format: "%.1f%%", hardwareMonitor.stats.cpuUsage))")
            Text("RAM: \(String(format: "%.1f GB", hardwareMonitor.stats.ramUsage))")
            Divider()
            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
