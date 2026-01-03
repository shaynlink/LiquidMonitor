import Foundation
import AppKit

@MainActor
class RootService: ObservableObject {
    @Published var isRootGranted: Bool = false
    @Published var isRunning: Bool = false
    @Published var currentPid: Int?
    @Published var error: String?
    
    private let metricsPath = "/tmp/liquidmonitor_metrics.plist"
    
    nonisolated func getMetricsPath() -> String {
        return "/tmp/liquidmonitor_metrics.plist"
    }
    
    func requestRootAccess() {
        // We use AppleScript to prompt for sudo password visually
        // We launch powermetrics in background, writing to a temp file
        // -i 1000: Sample every 1s
        // --format plist: Machine readable
        // -n 0: Unlimited samples (until killed)
        // echo $! returns the PID of the background process
        
        // Launch powermetrics in background with debug logging
        let debugLog = "/tmp/liquidmonitor_debug.log"
        // Use sh -c to ensure redirection works as expected
        // Removed -o, using standard redirection >
        // Added --show-initial-usage to ensure we get a block right away
        // Added battery, ane_power, sfi as requested for Processor page details
        // Redirect stderr to separate file for debugging
        // Use nohup to ensure process survives parent shell exit
        // Redirect stderr to separate file for debugging
        // Use trap '' HUP to ignore hangup signal when parent shell exits
        // Redirect stderr to separate file for debugging
        // Use nohup and redirect stdin from /dev/null to prevent TTY issues (Inappropriate ioctl)
        let cmdInner = "nohup /usr/bin/powermetrics -i 1000 --format plist -n 0 --buffer-size 0 --show-initial-usage -s cpu_power,gpu_power,thermal,battery,ane_power,sfi < /dev/null > \(metricsPath) 2> /tmp/liquidmonitor_error.log &"
        
        // We execute this directly in the extensive do shell script call, but RootService uses sh -c wrapper usually
        // Let's simplify and just pass this string to sh -c to be safe, or just run it directly?
        // safest is: sh -c 'nohup ... &'
        
        let command = "sh -c \"\(cmdInner)\" && echo $!"
        
        print("RootService: Executing: \(command)")
        
        // Wrap for AppleScript "do shell script ... with administrator privileges"
        // We must escape any double quotes in 'command' because it is inside "..."
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        guard let script = NSAppleScript(source: scriptSource) else {
            self.error = "Failed to create AppleScript"
            return
        }
        
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        
        if let err = errorInfo {
            self.error = "Root access denied or failed: \(err)"
            self.isRootGranted = false
            self.currentPid = nil
        } else {
            self.isRootGranted = true
            self.isRunning = true
            self.error = nil
            
            // Capture PID
            if let pidStr = result.stringValue, let pid = Int(pidStr) {
                print("Root Process started with PID: \(pid)")
                self.currentPid = pid
            }
        }
    }
    
    func stopRootProcess() {
        guard let pid = currentPid else {
            // Fallback or nothing to kill
            self.isRunning = false
            self.isRootGranted = false
            return
        }
        
        let command = "kill \(pid)"
        let scriptSource = "do shell script \"\(command)\" with administrator privileges"
        
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
        }
        
        self.currentPid = nil
        self.isRunning = false
        self.isRootGranted = false
    }
}
