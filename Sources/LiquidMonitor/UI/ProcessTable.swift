import SwiftUI

struct ProcessTable: View {
    @StateObject private var processProvider = ProcessProvider()
    @State private var sortOrder = [KeyPathComparator(\RunningProcessInfo.name)]
    @State private var selection = Set<Int32>()
    
    var body: some View {
        Table(processProvider.processes, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { process in
                HStack {
                    if let icon = process.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 16, height: 16)
                    }
                    Text(process.name)
                        .font(.body)
                }
            }
            
            TableColumn("PID", value: \.id) { process in
                 Text("\(process.id)")
                     .monospacedDigit()
            }
            .width(min: 60, max: 80)
            
            TableColumn("User", value: \.user) { process in
                Text(process.user)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, max: 120)

            TableColumn("Threads") { process in
                 Text("\(process.threadCount)")
                    .monospacedDigit()
            }
            .width(min: 60, max: 80)
            
            // Placeholder columns for now until we get real data
             TableColumn("CPU Time") { _ in Text("--") }
             TableColumn("% GPU") { _ in Text("--") }
        }
        .onChange(of: sortOrder) { _, newOrder in
            processProvider.processes.sort(using: newOrder)
        }
        .onAppear {
            processProvider.startMonitoring()
        }
        .onDisappear {
            processProvider.stopMonitoring()
        }
    }
}
