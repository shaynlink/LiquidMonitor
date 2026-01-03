import SwiftUI

@main
struct LiquidMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var hardwareMonitor = HardwareMonitor()
    @StateObject var batteryMonitor = BatteryMonitor()
    @StateObject var processProvider = ProcessProvider()
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup {
             RootView()
                .environmentObject(hardwareMonitor)
                .environmentObject(batteryMonitor)
                .environmentObject(processProvider)
                .onAppear {
                    hardwareMonitor.startMonitoring()
                    batteryMonitor.startMonitoring()
                    processProvider.startMonitoring()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}

struct RootView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        MainView()
            .preferredColorScheme(appTheme.colorScheme)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force app to be a regular app (shows in Dock, has UI)
        NSApp.setActivationPolicy(.regular)
        
        // Standard WindowGroup handles window creation now.
        // We just ensure activation policy is correct.
        print("LiquidMonitor: App launched with standard WindowGroup")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
