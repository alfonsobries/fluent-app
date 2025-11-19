import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Translate Tool Settings")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("OpenAI API Key")
                SecureField("sk-...", text: $settings.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading) {
                Text("Instructions (Prompt)")
                TextEditor(text: $settings.prompt)
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5)))
            }
            
            VStack(alignment: .leading) {
                Text("Shortcut")
                Text("Default: Cmd + Shift + O")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Future: Add shortcut recorder
            }
            
            Divider()
            
            HStack {
                if ClipboardService.shared.checkAccessibilityPermissions() {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accessibility Permissions Granted")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Accessibility Permissions Needed")
                    Button("Open Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .font(.caption)
            
            HStack {
                Spacer()
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
