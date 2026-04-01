import Combine
import Foundation

public final class AppController: ObservableObject {
    public let objectWillChange = ObservableObjectPublisher()

    public var settings: AppSettings {
        didSet {
            objectWillChange.send()
        }
    }

    public private(set) var state: State = .idle {
        didSet {
            objectWillChange.send()
        }
    }

    private let clipboardService: ClipboardServicing
    private let hotKeyManager: HotKeyManaging

    public init(
        settings: AppSettings,
        clipboardService: ClipboardServicing,
        hotKeyManager: HotKeyManaging
    ) {
        self.settings = settings
        self.clipboardService = clipboardService
        self.hotKeyManager = hotKeyManager

        bindHotKeys()
        settings.onShortcutsChanged = { [weak self] in
            self?.bindHotKeys()
        }
    }

    public var isProcessing: Bool {
        if case .processing = state {
            return true
        }
        return false
    }

    public var currentActionName: String? {
        if case .processing(let actionName) = state {
            return actionName
        }
        return nil
    }

    public func processSelection(with action: ShortcutAction) {
        guard !isProcessing else { return }

        guard clipboardService.checkAccessibilityPermissions(prompt: true) else {
            state = .failed("Accessibility permissions are required.")
            return
        }

        guard !settings.currentAPIKey.isEmpty else {
            state = .failed("Configure an API key for \(settings.selectedProvider.displayName).")
            return
        }

        state = .processing(action.name)

        guard let text = clipboardService.copySelectedText(), !text.isEmpty else {
            state = .failed("No text selection was found.")
            return
        }

        let provider = settings.currentProvider
        let apiKey = settings.currentAPIKey

        provider.processText(text: text, apiKey: apiKey, instructions: action.prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let response):
                    self.clipboardService.pasteText(response)
                    self.state = .completed(action.name)
                case .failure(let error):
                    self.state = .failed(error.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    public func clearTransientState() {
        state = .idle
    }

    public func pasteErrorMessageIfPossible(_ message: String) {
        guard clipboardService.checkAccessibilityPermissions(prompt: false) else {
            return
        }

        clipboardService.pasteText("Fluent App Error: \(message)")
    }

    private func bindHotKeys() {
        hotKeyManager.registerHotKeys(for: settings.enabledActions)
        hotKeyManager.onTrigger = { [weak self] action in
            self?.processSelection(with: action)
        }
    }
}

public extension AppController {
    enum State: Equatable {
        case idle
        case processing(String)
        case completed(String)
        case failed(String)
    }
}
