import AppKit
import Combine
import FluentCore
import FluentMacSupport
import SwiftUI
import UserNotifications

@main
struct FluentApp: App {
    @StateObject private var controller: AppController
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let controller = AppController.live()
        _controller = StateObject(wrappedValue: controller)
        AppDelegate.sharedController = controller
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var sharedController: AppController!

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []
    private var lastNotifiedState: AppController.State?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let controller = Self.sharedController else { return }

        log("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        bind(to: controller)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.log("opening settings window after launch")
            self.openSettingsWindow()
        }
    }

    private func setupStatusItem() {
        log("setupStatusItem")
        let menu = NSMenu()
        menu.delegate = self
        self.menu = menu

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = menu
        self.statusItem = statusItem
        rebuildMenu()
    }

    private func bind(to controller: AppController) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        controller.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem(for: controller.state)
                self?.rebuildMenu()
                self?.refreshSettingsWindow()
                self?.notifyIfNeeded(for: controller.state)
            }
            .store(in: &cancellables)

        updateStatusItem(for: controller.state)
    }

    private func updateStatusItem(for state: AppController.State) {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusBarImage(for: state)
        button.isHidden = false
        button.title = ""
        button.toolTip = tooltip(for: state)
        log("status item updated: \(button.toolTip ?? "Fluent")")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu, let controller = Self.sharedController else { return }

        menu.removeAllItems()

        let openItem = NSMenuItem(title: "Open Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)

        if case .failed(let message) = controller.state {
            let errorItem = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        if !controller.settings.enabledActions.isEmpty {
            menu.addItem(.separator())
            for action in controller.settings.enabledActions {
                let item = NSMenuItem(
                    title: "\(action.name)  \(action.shortcutDescription)",
                    action: #selector(runActionFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = action
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Fluent", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func refreshSettingsWindow() {
        guard let settingsWindow, let controller = Self.sharedController else { return }
        settingsWindow.contentViewController = NSHostingController(rootView: SettingsView(controller: controller))
    }

    @objc private func openSettingsFromMenu() {
        openSettingsWindow()
    }

    @objc private func runActionFromMenu(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ShortcutAction else { return }
        Self.sharedController.processSelection(with: action)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func openSettingsWindow() {
        guard let controller = Self.sharedController else { return }
        log("openSettingsWindow begin")

        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(controller: controller))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Fluent Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 920, height: 680))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
            log("created settings window")
        }

        refreshSettingsWindow()
        settingsWindow?.orderFrontRegardless()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        log("openSettingsWindow end")
    }

    private func notifyIfNeeded(for state: AppController.State) {
        guard state != lastNotifiedState else { return }
        lastNotifiedState = state

        switch state {
        case .failed(let message):
            notifyOrFallback(
                title: "Fluent Error",
                body: message,
                fallbackMessage: message,
                sound: true
            )
        case .completed(let actionName):
            notifyOrFallback(
                title: "Fluent",
                body: "\(actionName) completed.",
                fallbackMessage: nil,
                sound: false
            )
        default:
            return
        }
    }

    private func notifyOrFallback(title: String, body: String, fallbackMessage: String?, sound: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                if sound {
                    content.sound = .default
                }

                let request = UNNotificationRequest(
                    identifier: "fluent.\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request)
            case .denied, .notDetermined:
                guard let fallbackMessage, let controller = Self.sharedController else { return }
                DispatchQueue.main.async {
                    controller.pasteErrorMessageIfPossible(fallbackMessage)
                }
            @unknown default:
                break
            }
        }
    }

    private func tooltip(for state: AppController.State) -> String {
        switch state {
        case .idle:
            return "Fluent"
        case .processing(let actionName):
            return "Fluent: \(actionName)"
        case .completed(let actionName):
            return "Fluent: \(actionName) completed"
        case .failed(let message):
            return "Fluent error: \(message)"
        }
    }

    private func makeStatusBarImage(for state: AppController.State) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let color = NSColor.labelColor
        color.setStroke()
        color.setFill()

        let topLine = NSBezierPath()
        topLine.lineWidth = 1.8
        topLine.lineCapStyle = .round
        topLine.move(to: NSPoint(x: 3, y: 12.5))
        topLine.line(to: NSPoint(x: 13.5, y: 12.5))
        topLine.stroke()

        let topArrow = NSBezierPath()
        topArrow.lineWidth = 1.8
        topArrow.lineCapStyle = .round
        topArrow.lineJoinStyle = .round
        topArrow.move(to: NSPoint(x: 11, y: 15))
        topArrow.line(to: NSPoint(x: 14.8, y: 12.5))
        topArrow.line(to: NSPoint(x: 11, y: 10))
        topArrow.stroke()

        let bottomLine = NSBezierPath()
        bottomLine.lineWidth = 1.8
        bottomLine.lineCapStyle = .round
        bottomLine.move(to: NSPoint(x: 15, y: 5.5))
        bottomLine.line(to: NSPoint(x: 4.5, y: 5.5))
        bottomLine.stroke()

        let bottomArrow = NSBezierPath()
        bottomArrow.lineWidth = 1.8
        bottomArrow.lineCapStyle = .round
        bottomArrow.lineJoinStyle = .round
        bottomArrow.move(to: NSPoint(x: 7, y: 8))
        bottomArrow.line(to: NSPoint(x: 3.2, y: 5.5))
        bottomArrow.line(to: NSPoint(x: 7, y: 3))
        bottomArrow.stroke()

        switch state {
        case .processing:
            let dot = NSBezierPath(ovalIn: NSRect(x: 7, y: 7, width: 4, height: 4))
            dot.fill()
        case .failed:
            let badge = NSBezierPath(ovalIn: NSRect(x: 12, y: 1.5, width: 4.5, height: 4.5))
            badge.fill()
        default:
            break
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/fluent-launch.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}
