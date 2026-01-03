import SwiftUI

struct ProcessListView: View {
    @StateObject private var processProvider = ProcessProvider()
    var limit: Int? // Optional limit for dashboard preview
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row if needed, or just list
            ForEach(processProvider.processes.prefix(limit ?? processProvider.processes.count)) { process in
                HStack(spacing: 12) {
                    if let icon = process.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 24, height: 24)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(process.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Text("\(process.id)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    
                    Text(process.user)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                Divider()
            }
        }
        .onAppear {
            processProvider.startMonitoring()
        }
        .onDisappear {
            processProvider.stopMonitoring()
        }
    }
}
