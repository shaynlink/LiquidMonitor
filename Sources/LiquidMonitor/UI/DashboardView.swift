import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var hardwareMonitor: HardwareMonitor
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    @EnvironmentObject var processProvider: ProcessProvider
    
    // Grid layout for cards
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("System Overview")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Key Metrics Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    MetricCard(title: "CPU Load", value: String(format: "%.1f%%", hardwareMonitor.stats.cpuUsage), icon: "cpu") {
                        Chart(hardwareMonitor.cpuHistory.indices, id: \.self) { index in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Usage", hardwareMonitor.cpuHistory[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 40)
                    }
                    
                    MetricCard(title: "Memory Used", value: String(format: "%.1f GB", hardwareMonitor.stats.ramUsage), icon: "memorychip") {
                         ProgressView(value: hardwareMonitor.stats.ramUsage, total: hardwareMonitor.stats.totalRam)
                             .tint(.blue)
                         Text("of \(String(format: "%.0f GB", hardwareMonitor.stats.totalRam)) Total")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                    }
                    
                    MetricCard(title: "Battery", value: "\(Int(batteryMonitor.batteryInfo.level * 100))%", icon: batteryMonitor.batteryInfo.isCharging ? "battery.100.bolt" : "battery.100") {
                        HStack {
                            ProgressView(value: batteryMonitor.batteryInfo.level)
                                .tint(.green)
                            Spacer()
                            Text(batteryMonitor.batteryInfo.timeRemaining > 0 ? "\(batteryMonitor.batteryInfo.timeRemaining) min" : "Calculating...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Advanced Charts (Full Width)
                VStack(spacing: 16) {
                     CPUCoresChart(
                        history: hardwareMonitor.perCoreHistory,
                        eCoreCount: hardwareMonitor.efficiencyCoreCount,
                        pCoreCount: hardwareMonitor.performanceCoreCount
                     )
                     CPUAppsChart(processProvider: processProvider)
                     CPUAppsHistoryChart(processProvider: processProvider)
                }
                .padding(.horizontal)
                
                // Active Processes Preview (Top 5)
                VStack(alignment: .leading) {
                    Text("Top Processes")
                        .font(.headline)
                        .padding(.bottom, 8)
                    
                    ProcessListView(limit: 5) // We will update ProcessListView to be a simple list or table
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
}
