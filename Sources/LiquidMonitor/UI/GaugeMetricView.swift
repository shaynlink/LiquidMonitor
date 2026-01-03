import SwiftUI

struct GaugeMetricView: View {
    let title: String
    let value: Double
    let color: Color
    
    // Dynamic gradient based on the provided color
    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [color.opacity(0.3), color]),
            center: .center,
            startAngle: .degrees(135),
            endAngle: .degrees(405)
        )
    }
    
    var body: some View {
        VStack(spacing: 4) {
             Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
            
            ZStack {
                // Background Track
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(135))
                
                // Value Track (Fill)
                // We map 0-100 to 0.0-0.75
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value, 100) / 100 * 0.75))
                    .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
                
                // Value Text
                Text(String(format: "%.1f", value))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
            }
            .frame(width: 60, height: 60)
            .padding(.bottom, -15) // Pull up slightly because of the semi-circle
        }
    }
}
