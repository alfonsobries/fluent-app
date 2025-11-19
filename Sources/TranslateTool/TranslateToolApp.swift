import SwiftUI

@main
struct TranslateToolApp: App {
    @StateObject var controller = AppController.shared
    
    var body: some Scene {
        MenuBarExtra("Translate Tool", systemImage: controller.isProcessing ? "hourglass" : "globe") {
            SettingsView(settings: controller.settings)
        }
        .menuBarExtraStyle(.window)
    }
}
