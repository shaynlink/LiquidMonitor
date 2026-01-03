import SwiftUI
import Charts

struct CPUCoresChart: View {
    let history: [[Double]] // Per core history
    let eCoreCount: Int
    let pCoreCount: Int
    
    // Per-core latest values
    private var currentLoadPerCore: [Double] {
        return history.map { $0.last ?? 0.0 }
    }
    
    var body: some View {
        MetricCard(title: "CPU Cores", value: "\(history.count) Cores", icon: "cpu") {
            VStack(alignment: .leading, spacing: 16) {
                // Efficiency Cluster
                if eCoreCount > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.green)
                            Text("Efficiency Cluster")
                                .font(.headline)
                        }
                        .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 12)], spacing: 12) {
                            ForEach(0..<min(eCoreCount, currentLoadPerCore.count), id: \.self) { index in
                                GaugeMetricView(
                                    title: "E\(index + 1)",
                                    value: currentLoadPerCore[index],
                                    color: pressureColor(for: currentLoadPerCore[index])
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // Performance Cluster
                if pCoreCount > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                            Text("Performance Cluster")
                                .font(.headline)
                        }
                        .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 12)], spacing: 12) {
                            ForEach(0..<pCoreCount, id: \.self) { i in
                                let index = eCoreCount + i
                                if index < currentLoadPerCore.count {
                                    GaugeMetricView(
                                        title: "P\(i + 1)",
                                        value: currentLoadPerCore[index],
                                        color: pressureColor(for: currentLoadPerCore[index])
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func pressureColor(for load: Double) -> Color {
        switch load {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}

struct CPUAppsChart: View {
    @ObservedObject var processProvider: ProcessProvider
    
    let threshold: Double = 10.0
    
    private var chartData: [ChartData] {
        let sortedApps = processProvider.processes.sorted { $0.cpuUsage > $1.cpuUsage }
        
        // Always take Top 5
        var finalApps: [ChartData] = []
        let topApps = sortedApps.prefix(5)
        
        for (index, app) in topApps.enumerated() {
            finalApps.append(ChartData(
                name: app.name,
                value: app.cpuUsage,
                color: Color.distinct(seed: app.name)
            ))
        }
        
        // Others
        if sortedApps.count > 5 {
            let othersTotal = sortedApps.dropFirst(5).reduce(0) { $0 + $1.cpuUsage }
            if othersTotal > 0 {
                finalApps.append(ChartData(name: "Others", value: othersTotal, color: .gray))
            }
        }
        
        return finalApps
    }
    
    struct ChartData: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let value: Double
        let color: Color
    }
    
    var body: some View {
        MetricCard(title: "App Breakdown", value: "Top Consumers", icon: "chart.pie") {
            HStack(spacing: 20) {
                // DONUT CHART
                Chart(chartData) { item in
                    SectorMark(
                        angle: .value("Load", item.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(item.color)
                }
                .frame(height: 150)
                .animation(.easeInOut, value: chartData)
                
                // LEGEND
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(chartData) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .lineLimit(1)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f%%", item.value))
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 150)
            }
        }
    }
}

struct CPUAppsHistoryChart: View {
    @ObservedObject var processProvider: ProcessProvider
    
    struct ChartPoint: Identifiable {
        var id: String { "\(name)_\(date.timeIntervalSince1970)" }
        let date: Date
        let name: String
        let value: Double
        let color: Color
    }
    
    private var normalizedData: [ChartPoint] {
        let snapshots = processProvider.history
        guard !snapshots.isEmpty else { return [] }
        
        // 1. Collect all unique apps and their colors
        var appColors: [String: Color] = [:]
        for snapshot in snapshots {
            for app in snapshot.apps {
                if appColors[app.name] == nil {
                    appColors[app.name] = app.color
                }
            }
        }
        
        let allNames = appColors.keys.sorted()
        var points: [ChartPoint] = []
        
        // 2. Normalize
        for snapshot in snapshots {
            let appMap = Dictionary(uniqueKeysWithValues: snapshot.apps.map { ($0.name, $0) })
            
            for name in allNames {
                if let app = appMap[name] {
                    points.append(ChartPoint(date: snapshot.timestamp, name: app.name, value: app.value, color: app.color))
                } else {
                    // Fill missing with 0
                    if let color = appColors[name] {
                        points.append(ChartPoint(date: snapshot.timestamp, name: name, value: 0, color: color))
                    }
                }
            }
        }
        return points
    }
    
    var body: some View {
        let data = normalizedData
        // Fix crash: Deduplicate keys for color mapping
        let uniqueAppNames = Set(data.map { $0.name })
        let colorMapping = Dictionary(uniqueKeysWithValues: uniqueAppNames.map { name in
            (name, data.first(where: { $0.name == name })?.color ?? .gray)
        })
        
        return MetricCard(title: "Real-time History", value: "Last 20s", icon: "waveform.path.ecg") {
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.date, unit: .second),
                    y: .value("Load", point.value)
                )
                .foregroundStyle(by: .value("App", point.name))
            }
            .chartForegroundStyleScale(domain: colorMapping.keys.sorted(), range: colorMapping.keys.sorted().map { colorMapping[$0] ?? .gray })
            .chartLegend(.hidden)
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.hour().minute().second())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding(.top, 10)
        }
    }
}
