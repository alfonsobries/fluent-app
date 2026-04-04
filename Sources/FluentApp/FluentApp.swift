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
            SettingsView(controller: controller)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var sharedController: AppController!

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var statusSpinner: NSProgressIndicator?
    private let hudController = ProcessingHUDController()
    private var cancellables: Set<AnyCancellable> = []
    private var lastNotifiedState: AppController.State?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let controller = Self.sharedController else { return }

        log("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        bind(to: controller)
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
        installStatusSpinnerIfNeeded()
        rebuildMenu()
    }

    private func bind(to controller: AppController) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        controller.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem(for: controller.state)
                self?.rebuildMenu()
                self?.updateHUD(for: controller.state)
                self?.notifyIfNeeded(for: controller.state)
            }
            .store(in: &cancellables)

        updateStatusItem(for: controller.state)
    }

    private func updateStatusItem(for state: AppController.State) {
        guard let button = statusItem?.button else { return }

        switch state {
        case .processing:
            installStatusSpinnerIfNeeded()
            statusSpinner?.isHidden = false
            statusSpinner?.startAnimation(nil)
            button.image = nil
        default:
            statusSpinner?.stopAnimation(nil)
            statusSpinner?.isHidden = true
            button.image = makeStatusBarImage(for: state)
        }

        button.isHidden = false
        button.title = ""
        button.toolTip = tooltip(for: state)
        log("status item updated: \(button.toolTip ?? "Fluent App")")
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
        let quitItem = NSMenuItem(title: "Quit Fluent App", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openSettingsFromMenu() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func runActionFromMenu(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ShortcutAction else { return }
        Self.sharedController.processSelection(with: action)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func notifyIfNeeded(for state: AppController.State) {
        guard state != lastNotifiedState else { return }
        lastNotifiedState = state

        switch state {
        case .failed(let message):
            notifyOrFallback(
                title: "Fluent App Error",
                body: message,
                fallbackMessage: message,
                sound: true
            )
        default:
            return
        }
    }

    private func updateHUD(for state: AppController.State) {
        switch state {
        case .processing(let actionName):
            hudController.show(message: processingMessage(for: actionName))
        default:
            hudController.hide()
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
            return "Fluent App"
        case .processing(let actionName):
            return "Fluent App: \(actionName)"
        case .completed(let actionName):
            return "Fluent App: \(actionName) completed"
        case .failed(let message):
            return "Fluent App error: \(message)"
        }
    }

    private func processingMessage(for actionName: String) -> String {
        let normalized = actionName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "translate":
            return "Translating"
        case "improve writing":
            return "Improving"
        case "fix grammar":
            return "Fixing grammar"
        case "summarize":
            return "Summarizing"
        case "make professional":
            return "Rewriting"
        default:
            return "Processing"
        }
    }

    private func installStatusSpinnerIfNeeded() {
        guard statusSpinner == nil, let button = statusItem?.button else { return }

        let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        button.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        statusSpinner = spinner
    }

    private func makeStatusBarImage(for state: AppController.State) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let color = NSColor.labelColor
        color.setStroke()
        color.setFill()

        let bubble = NSBezierPath()
        bubble.lineWidth = 1.8
        bubble.lineJoinStyle = .round
        bubble.lineCapStyle = .round
        bubble.move(to: NSPoint(x: 2.6, y: 10.3))
        bubble.curve(to: NSPoint(x: 3.8, y: 14.2), controlPoint1: NSPoint(x: 2.5, y: 11.9), controlPoint2: NSPoint(x: 2.8, y: 13.2))
        bubble.curve(to: NSPoint(x: 8.7, y: 15.8), controlPoint1: NSPoint(x: 5.0, y: 15.4), controlPoint2: NSPoint(x: 6.8, y: 15.9))
        bubble.curve(to: NSPoint(x: 14.4, y: 14.3), controlPoint1: NSPoint(x: 10.7, y: 15.8), controlPoint2: NSPoint(x: 12.8, y: 15.3))
        bubble.curve(to: NSPoint(x: 16.1, y: 9.4), controlPoint1: NSPoint(x: 15.6, y: 13.2), controlPoint2: NSPoint(x: 16.2, y: 11.5))
        bubble.curve(to: NSPoint(x: 13.2, y: 5.6), controlPoint1: NSPoint(x: 16.0, y: 7.6), controlPoint2: NSPoint(x: 15.0, y: 6.3))
        bubble.curve(to: NSPoint(x: 8.1, y: 4.8), controlPoint1: NSPoint(x: 11.8, y: 5.1), controlPoint2: NSPoint(x: 9.8, y: 4.8))
        bubble.curve(to: NSPoint(x: 4.9, y: 3.4), controlPoint1: NSPoint(x: 6.8, y: 4.8), controlPoint2: NSPoint(x: 5.7, y: 4.4))
        bubble.curve(to: NSPoint(x: 4.6, y: 1.9), controlPoint1: NSPoint(x: 4.5, y: 2.9), controlPoint2: NSPoint(x: 4.4, y: 2.3))
        bubble.curve(to: NSPoint(x: 5.7, y: 3.3), controlPoint1: NSPoint(x: 5.1, y: 2.2), controlPoint2: NSPoint(x: 5.4, y: 2.7))
        bubble.curve(to: NSPoint(x: 2.6, y: 10.3), controlPoint1: NSPoint(x: 3.6, y: 4.0), controlPoint2: NSPoint(x: 2.4, y: 6.8))
        bubble.close()
        bubble.stroke()

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
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}

private final class ProcessingHUDController {
    private let model = ProcessingHUDModel()
    private lazy var panel: NSPanel = {
        let hostingController = NSHostingController(rootView: ProcessingHUDView(model: model))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 170, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }()

    func show(message: String) {
        model.message = message
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let topInset = max(20.0, screen.frame.maxY - frame.maxY)
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.maxY - panel.frame.height - topInset - 6
        )
        panel.setFrameOrigin(origin)
    }
}

private final class ProcessingHUDModel: ObservableObject {
    @Published var message = "Working"
}

private struct ProcessingHUDView: View {
    @ObservedObject var model: ProcessingHUDModel
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.8)

                Circle()
                    .trim(from: 0.0, to: 0.34)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            }
            .frame(width: 12, height: 12)

            Text(verbatim: "\(model.message)…")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .frame(width: 170, height: 38, alignment: .leading)
        .onAppear {
            isAnimating = true
        }
    }
}
