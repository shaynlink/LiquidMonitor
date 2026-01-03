import SwiftUI

struct SpeedometerGauge: View {
    let value: Double // 0.0 to 1.0
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                
                // Value Arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + (0.7 * min(value, 1.0)))
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [color.opacity(0.7), color]), center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .animation(.spring(response: 0.8), value: value)
                
                // Value Text
                VStack(spacing: 0) {
                    Text("\(Int(value * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                    
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(height: 100)
        }
    }
}
