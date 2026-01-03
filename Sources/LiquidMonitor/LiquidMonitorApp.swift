import SwiftUI

@main
struct LiquidMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var hardwareMonitor = HardwareMonitor()
    @StateObject var batteryMonitor = BatteryMonitor()
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup(id: "dashboard") {
             // Main content is managed by AppDelegate to ensure visibility,
             // but we keep this here for structure if we want to move back to standard lifecycle later.
             // Currently, AppDelegate creates the window.
             // WE NEED TO INJECT THE THEME INTO THE APP DELEGATE'S WINDOW or VIEW.
             // Since AppDelegate manually creates the window with MainView, we should handle it there.
             // However, for pure SwiftUI App lifecycle mixed with AppKit, let's try applying it to the view created in AppDelegate.
             EmptyView()
        }

    }
}

// Ensure AppTheme is available globally or move it to a shared model file.
// For now, assume it's in SettingsView.swift or move it to its own file if build fails.
// To avoid circular dependency or visibility issues, better to move AppTheme to a separate file.
// But first, let's update AppDelegate to respect the theme.

struct RootView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @EnvironmentObject var hardwareMonitor: HardwareMonitor
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    @EnvironmentObject var processProvider: ProcessProvider
    
    var body: some View {
        MainView()
            .preferredColorScheme(appTheme.colorScheme)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var window: NSWindow!
    @Published var hardwareMonitor = HardwareMonitor()
    @Published var batteryMonitor = BatteryMonitor()
    @Published var processProvider = ProcessProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force app to be a regular app (shows in Dock, has UI)
        NSApp.setActivationPolicy(.regular)
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = RootView()
            .environmentObject(hardwareMonitor)
            .environmentObject(batteryMonitor)
            .environmentObject(processProvider)

        // Create the window and set the content view.
        // Increased default size for Pro content
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Pro Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.title = "LiquidMonitor Pro"
        
        // Customize toolbar/titlebar style for sidebar feel
        window.toolbarStyle = .unified
        
        showWindow()
        
        // Start monitoring
        hardwareMonitor.startMonitoring()
        batteryMonitor.startMonitoring()
        processProvider.startMonitoring()
        
        print("LiquidMonitor: Pro Window created and ordered front")
    }
    
    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hardwareMonitor.stopMonitoring()
        batteryMonitor.stopMonitoring()
        processProvider.stopMonitoring()
    }
}
