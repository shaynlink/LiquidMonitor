import SwiftUI

enum AppTab: Hashable {
    case general
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
        } detail: {
            switch selectedTab {
            case .general:
                DashboardView()
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
