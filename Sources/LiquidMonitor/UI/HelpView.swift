import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("User Guide")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Group {
                    Text("Overview")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("LiquidMonitor allows you to visualize your system's performance in real-time with a beautiful liquid interface.")
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Group {
                    Text("Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        FeatureRow(icon: "cpu", title: "CPU Monitoring", description: "Real-time CPU usage graph and stats.")
                        FeatureRow(icon: "memorychip", title: "RAM Usage", description: "Track active memory usage.")
                        FeatureRow(icon: "battery.100", title: "Battery Health", description: "Monitor battery level and charging status.")
                        FeatureRow(icon: "list.bullet", title: "Process List", description: "View running applications and their PIDs.")
                    }
                }
                
                Group {
                    Text("Menu Bar")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Click the Pulse icon in the menu bar to see quick stats or quit the application.")
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Button("Close") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(LiquidBackground())
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
