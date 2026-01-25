import SwiftUI

@main
struct FluentApp: App {
    @StateObject var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            SettingsView(settings: controller.settings)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: controller.isProcessing ? "hourglass" : "globe")
                if controller.isProcessing, let actionName = controller.currentActionName {
                    Text(actionName)
                        .font(.caption)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
