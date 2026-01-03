import SwiftUI
import Charts

struct LoadAverageChart: View {
    let history: [[Double]] // Each element is [1m, 5m, 15m]
    
    var body: some View {
        MetricCard(title: "Load Average (1m/5m/15m)", value: formattedCurrent, icon: "gauge") {
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, loads in
                    if loads.count >= 3 {
                        LineMark(
                            x: .value("Time", index),
                            y: .value("1m", loads[0])
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Time", index),
                            y: .value("5m", loads[1])
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Time", index),
                            y: .value("15m", loads[2])
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis(.hidden)
            .chartForegroundStyleScale([
                "1 min": .blue,
                "5 min": .purple,
                "15 min": .orange
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 150)
        }
    }
    
    private var formattedCurrent: String {
        guard let last = history.last, last.count >= 3 else { return "-" }
        return String(format: "%.2f", last[0])
    }
}
