import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            }
            
            Section("About") {
                Text("LiquidMonitor Pro")
                Text("Version 26.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Done") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
