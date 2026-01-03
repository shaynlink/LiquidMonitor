import SwiftUI
import Charts

struct ProcessorView: View {
    @EnvironmentObject var hardwareMonitor: HardwareMonitor
    @EnvironmentObject var processProvider: ProcessProvider
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Processor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(hardwareMonitor.cpuBrand)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    // Quick Stats Badge
                    HStack(spacing: 20) {
                        VStack(alignment: .trailing) {
                            Text("Total Cores")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(hardwareMonitor.performanceCoreCount + hardwareMonitor.efficiencyCoreCount)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .trailing) {
                            Text("Architecture")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Apple Silicon")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Real-time Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(title: "System Uptime", value: formatUptime(hardwareMonitor.uptime), icon: "clock") {
                        Text("Since last boot")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    MetricCard(title: "Processes", value: "\(hardwareMonitor.processCount)", icon: "rectangle.stack") {
                         Text("Active Tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    MetricCard(title: "Ctx Switches", value: "\(hardwareMonitor.contextSwitchesRate)/s", icon: "arrow.triangle.2.circlepath") {
                         Text("Total: \(hardwareMonitor.contextSwitchesTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Sparkline for CPU Load
                    SparklineMetricCard(
                        title: "CPU Load",
                        value: String(format: "%.1f%%", hardwareMonitor.cpuUsageTotal),
                        data: hardwareMonitor.cpuHistory,
                        color: cpuPressureColor(for: hardwareMonitor.cpuUsageTotal)
                    )
                    
                    MetricCard(title: "Thermal State", value: formatThermalState(hardwareMonitor.thermalState), icon: "thermometer") {
                        Text("Current limit status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    SparklineMetricCard(
                        title: "GPU Usage",
                        value: String(format: "%.1f%%", hardwareMonitor.gpuUsage),
                        data: hardwareMonitor.gpuHistory,
                        color: gpuPressureColor()
                    )
                }
                .padding(.horizontal)
                
                // Phase 3: Gauges
                HStack(spacing: 16) {
                    MetricCard(title: "System Load", value: "", icon: "speedometer") {
                         SpeedometerGauge(
                            value: min((hardwareMonitor.loadAverage[0] / Double(hardwareMonitor.performanceCoreCount + hardwareMonitor.efficiencyCoreCount)), 1.0),
                            title: "Pressure",
                            color: loadPressureColor()
                         )
                         .frame(maxWidth: .infinity)
                    }
                    
                    MetricCard(title: "GPU Load", value: "", icon: "display") {
                        SpeedometerGauge(
                            value: hardwareMonitor.gpuUsage / 100.0,
                            title: "Usage",
                            color: gpuPressureColor()
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Static Specifications (Phase 2)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specifications")
                        .font(.headline)
                        .padding(.horizontal)
                        
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            SpecCard(title: "L1 Cache (I/D)", value: "\(formatBytes(hardwareMonitor.l1ICacheSize)) / \(formatBytes(hardwareMonitor.l1DCacheSize))")
                            SpecCard(title: "L2 Cache", value: formatBytes(hardwareMonitor.l2CacheSize))
                            SpecCard(title: "Features", value: hardwareMonitor.cpuFeatures.joined(separator: ", "))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                // Experimental Features (Phase 4)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Experimental Features", systemImage: "flask.fill")
                            .font(.headline)
                            .foregroundStyle(.purple)
                        Spacer()
                        if !hardwareMonitor.isRootMode {
                            Button(action: {
                                hardwareMonitor.rootService.requestRootAccess()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.open.fill")
                                    Text("Enable Advanced Metrics")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if !hardwareMonitor.isRootMode {
                         Text("Some metrics are estimated. Enable Advanced Metrics for accurate real-time data.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        if hardwareMonitor.isRootMode && !hardwareMonitor.cpuFrequencyClusters.isEmpty {
                            ForEach(hardwareMonitor.cpuFrequencyClusters.keys.sorted(), id: \.self) { clusterName in
                                MetricCard(title: "Freq (\(clusterName))", value: String(format: "%.1f GHz", hardwareMonitor.cpuFrequencyClusters[clusterName] ?? 0.0), icon: "cpu") {
                                    Text("Real-time")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                        } else {
                            // Fallback for non-root or initialization
                             MetricCard(title: "Freq (P-Core)", value: "Nominal", icon: "cpu") {
                                 Label("Estimated", systemImage: "exclamationmark.triangle.fill")
                                     .font(.caption2)
                                     .foregroundStyle(.orange)
                             }
                             MetricCard(title: "Freq (E-Core)", value: "Nominal", icon: "cpu") {
                                 Label("Estimated", systemImage: "exclamationmark.triangle.fill")
                                     .font(.caption2)
                                     .foregroundStyle(.orange)
                             }
                        }
                        
                        MetricCard(title: "Battery Current", value: "\(hardwareMonitor.batteryCurrent) mA", icon: "bolt.battery.block") {
                            Text(hardwareMonitor.batteryCurrent < 0 ? "Discharging" : "Charging/Idle")
                                .font(.caption)
                                .foregroundStyle(hardwareMonitor.batteryCurrent < 0 ? .orange : .green)
                        }
                        
                        MetricCard(title: "Neural Engine", value: hardwareMonitor.isNeuralEngineActive ? "Active" : "Idle", icon: "brain.head.profile") {
                             HStack {
                                Circle()
                                    .fill(hardwareMonitor.isNeuralEngineActive ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: hardwareMonitor.isNeuralEngineActive ? .green : .clear, radius: 4)
                                Text(hardwareMonitor.isNeuralEngineActive ? "Processing" : "Standby")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        MetricCard(title: "CPU Thermal", value: formatThermalState(hardwareMonitor.thermalState), icon: "flame") {
                            Text("Limit Status (Proxy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Visualizations
                VStack(spacing: 20) {
                    Text("Core Activity")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Reusing the existing Core Chart
                    CPUCoresChart(
                        history: hardwareMonitor.perCoreHistory,
                        eCoreCount: hardwareMonitor.efficiencyCoreCount,
                        pCoreCount: hardwareMonitor.performanceCoreCount
                    )
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                        
                    // Load Average Section
                    Text("System Load")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                    LoadAverageChart(history: hardwareMonitor.loadAverageHistory)
                        .padding(.horizontal)
                    
                    Text("Load History")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Reusing the History Chart
                    // Reusing the History Chart
                    CPUTotalLoadAreaChart(
                        history: hardwareMonitor.perCoreHistory,
                        eCoreCount: hardwareMonitor.efficiencyCoreCount,
                        pCoreCount: hardwareMonitor.performanceCoreCount
                    )
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.bottom)
        }
    }
    
    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "0m"
    }
    
    private func calculateLoadPressure() -> String {
        let totalCores = Double(hardwareMonitor.performanceCoreCount + hardwareMonitor.efficiencyCoreCount)
        if totalCores == 0 { return "0%" }
        let pressure = (hardwareMonitor.loadAverage[0] / totalCores) * 100
        return String(format: "%.0f%%", pressure)
    }
    
    // CPU Pressure Color Helper
    private func cpuPressureColor(for usage: Double) -> Color {
        switch usage {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    private func loadPressureColor() -> Color {
        let totalCores = Double(hardwareMonitor.performanceCoreCount + hardwareMonitor.efficiencyCoreCount)
        if totalCores == 0 { return .green }
        let pressure = hardwareMonitor.loadAverage[0] / totalCores
        
        switch pressure {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    private func gpuPressureColor() -> Color {
        switch hardwareMonitor.gpuUsage {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    private func formatThermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct SpecCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
