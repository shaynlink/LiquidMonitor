import SwiftUI

enum AppTab: Hashable {
    case general
    case processor
    case memory
    case energy
}

struct MainView: View {
    @State private var selectedTab: AppTab? = .general
    @EnvironmentObject var hardwareMonitor: HardwareMonitor
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Monitor") {
                    NavigationLink(value: AppTab.general) {
                        Label("General", systemImage: "macwindow")
                    }
                    NavigationLink(value: AppTab.processor) {
                        Label("Processor", systemImage: "cpu")
                    }
                    NavigationLink(value: AppTab.memory) {
                        Label("Memory", systemImage: "memorychip")
                    }
                    NavigationLink(value: AppTab.energy) {
                        Label("Energy", systemImage: "bolt.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if !hardwareMonitor.isRootMode {
                            hardwareMonitor.rootService.requestRootAccess()
                        }
                    } label: {
                        Label("Root Access", systemImage: hardwareMonitor.isRootMode ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(hardwareMonitor.isRootMode ? .green : .primary)
                    }
                    .help(hardwareMonitor.isRootMode ? "Root privileges granted" : "Enable detailed metrics (requires Root)")
                    .disabled(hardwareMonitor.isRootMode) // Disable if already active? Or allow re-request? User might want to stop it?
                    // User said "launch all processes". Usually means "enable".
                    // Let's just allow clicking it. If active, maybe show it's active.
                }
            }
        } detail: {
            switch selectedTab {
            case .general:
                DashboardView()
            case .processor:
                ProcessorView()
            case .memory:
                ProcessTable()
            case .energy:
                Text("Energy Detail View - Coming Soon")
            case .none:
                Text("Select an item")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
