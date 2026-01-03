import SwiftUI
import Charts

struct CPUTotalLoadAreaChart: View {
    let history: [[Double]] // [CoreIndex][TimeIndex]
    let eCoreCount: Int
    let pCoreCount: Int
    
    struct ChartData: Identifiable {
        var id: String { "\(coreName)_\(timeIndex)" }
        let timeIndex: Int
        let coreName: String
        let value: Double
        let color: Color
    }
    
    private var coreNames: [String] {
        var names: [String] = []
        for i in 0..<eCoreCount { names.append("E\(i+1)") }
        for i in 0..<pCoreCount { names.append("P\(i+1)") }
        // Fallback if counts don't match history size
        while names.count < history.count { names.append("C\(names.count + 1)") }
        return names
    }
    
    // Distinct High-Contrast Palette
    // Avoiding similar light colors.
    private let palette: [Color] = [
        .red, .blue, .green, .orange, .purple,
        .cyan, .brown, .yellow, .indigo, .mint,
        .gray, .teal, .pink // Pink is distinct from Red if saturation is high
    ]
    
    private var chartData: [ChartData] {
        var data: [ChartData] = []
        guard let firstCore = history.first else { return [] }
        let timePoints = firstCore.count
        let names = coreNames
        
        for t in 0..<timePoints {
            for c in 0..<history.count {
                if t < history[c].count {
                    data.append(ChartData(
                        timeIndex: t,
                        coreName: names.indices.contains(c) ? names[c] : "C\(c)",
                        value: history[c][t],
                        color: palette[c % palette.count]
                    ))
                }
            }
        }
        return data
    }

    var body: some View {
        let maxLoad = Double((eCoreCount + pCoreCount) * 100)
        let data = chartData
        
        // Calculate Current Total Load (sum of all cores at the last time index)
        let totalVal = history.reduce(0.0) { result, coreHist in
            result + (coreHist.last ?? 0.0)
        }
        
        // Extract unique cores for Legend
        let uniqueCores = Array(Set(data.map { $0.coreName })).sorted { 
            let type1 = $0.prefix(1)
            let type2 = $1.prefix(1)
            if type1 != type2 { return type1 < type2 }
            let num1 = Int($0.dropFirst()) ?? 0
            let num2 = Int($1.dropFirst()) ?? 0
            return num1 < num2
        }
        
        MetricCard(title: "Cumulative Load", value: "Capacity: \(Int(maxLoad))%", icon: "waveform.path.ecg") {
            VStack(spacing: 12) {
                Chart {
                    ForEach(data) { point in
                        AreaMark(
                            x: .value("Time", point.timeIndex),
                            y: .value("Load", point.value)
                        )
                        .foregroundStyle(by: .value("Core", point.coreName))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Current Total Indicator (Left Side)
                    RuleMark(y: .value("Current Load", totalVal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2]))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    // Max Capacity Line
                    RuleMark(y: .value("Max Capacity", maxLoad))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .chartForegroundStyleScale(domain: uniqueCores, range: uniqueCores.enumerated().map { palette[$0.offset % palette.count] })
                .chartYScale(domain: 0...maxLoad)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing)
                }
                .chartLegend(.hidden)
                // Use overlay for labels to keep them safely inside bounds without being clipped by chart area
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            // Max Capacity Label
                            if let yPos = proxy.position(forY: maxLoad) {
                                Text("Max: \(Int(maxLoad))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .position(x: 35, y: yPos - 10) // Offset -10 to sit above line
                            }
                            
                            // Current Load Label
                            if let yPos = proxy.position(forY: totalVal) {
                                Text("\(Int(totalVal))%")
                                    .font(.caption2.bold())
                                    .padding(4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                                    .foregroundStyle(.white)
                                    .position(x: 25, y: yPos) 
                            }
                        }
                    }
                }
                .frame(height: 200)
                
                // Custom Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(uniqueCores, id: \.self) { name in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(palette[uniqueCores.firstIndex(of: name)! % palette.count])
                                    .frame(width: 8, height: 8)
                                Text(name)
                                    .font(.caption2)
                                    .bold()
                            }
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
    }
}
