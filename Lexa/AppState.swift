import AppKit
import Observation

/// Coordinates hotkey → capture selection → LLM → suggestion panel → replace.
@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case needsAccessibility
        case noSelection
        case ready
        case working
        case done
        case failed(String)
    }

    let preferences = Preferences()
    let updater = Updater()
    var phase: Phase = .idle
    var action: WritingAction = .fix
    var original = ""
    var output = ""
    var result = ""
    var segments: [DiffSegment] = []
    var showChanges = true
    var copied = false
    var accessibilityGranted = Accessibility.isTrusted
    var hotKeyRegistered = true

    @ObservationIgnored private let bridge = TextBridge()
    @ObservationIgnored private let hotKeys = HotKeyManager()
    @ObservationIgnored private lazy var panel = SuggestionPanelController(state: self)
    @ObservationIgnored private lazy var settingsWindow = SettingsWindowController(state: self)
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var apiKeys: [String: String] = [:]

    var provider: Provider { preferences.provider }
    var model: String { preferences.model(for: provider) }
    var liveText: String { ResponseCleaner.stripThinking(output).trimmingCharacters(in: .whitespacesAndNewlines) }
    var isUnchanged: Bool { phase == .done && result == original }
    var hasSelection: Bool { !original.isEmpty }

    var providerSummary: String {
        let model = model.isEmpty ? "default model" : model
        return "\(provider.name) · \(model)"
    }

    func start() {
        hotKeys.onPress = { [weak self] in self?.checkSelection() }
        registerHotKey()
        updater.setAutomatic(preferences.findUpdates)
        if !preferences.hasCompletedSetup {
            preferences.hasCompletedSetup = true
            showSettings()
        }
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--demo") {
            let next = CommandLine.arguments.dropFirst(index + 1).first.flatMap { $0.hasPrefix("--") ? nil : $0 }
            let text = next ?? "Their going to the libary tomorow, and they wants me to come to."
            original = text
            panel.show()
            run(preferences.defaultAction)
        }
        #endif
    }

    // MARK: - Hotkey

    func registerHotKey() {
        hotKeyRegistered = hotKeys.register(preferences.hotKey)
    }

    func suspendHotKey() {
        hotKeys.unregister()
    }

    // MARK: - Flow

    func checkSelection(fromMenu: Bool = false) {
        Task { await captureAndRun(delay: fromMenu ? .milliseconds(200) : .zero) }
    }

    private func captureAndRun(delay: Duration) async {
        task?.cancel()
        if panel.isVisible {
            panel.close()
            try? await Task.sleep(for: .milliseconds(120))
        }
        if delay > .zero { try? await Task.sleep(for: delay) }

        accessibilityGranted = Accessibility.isTrusted
        guard accessibilityGranted else {
            reset(phase: .needsAccessibility)
            panel.show()
            return
        }
        guard let text = await bridge.captureSelection(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            reset(phase: .noSelection)
            panel.show()
            return
        }
        reset(phase: .ready)
        original = text
        panel.show()
        if preferences.autoRun { run(preferences.defaultAction) }
    }

    func run(_ action: WritingAction) {
        guard hasSelection else { return }
        task?.cancel()
        self.action = action
        output = ""
        result = ""
        segments = []
        copied = false
        phase = .working

        let backend = makeBackend(for: provider)
        let request = PromptBuilder.request(action: action, text: original, model: model)
        let original = original
        task = Task {
            do {
                for try await update in backend.stream(request) {
                    switch update {
                    case .append(let text): output += text
                    case .replace(let text): output = text
                    }
                }
                try Task.checkCancellation()
                let cleaned = ResponseCleaner.clean(output, original: original)
                guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw LLMError("The model sent an empty result. Try again, or select a different model.")
                }
                result = cleaned
                segments = action.showsDiff ? TextDiff.diff(original, cleaned) : []
                phase = .done
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func retry() {
        run(action)
    }

    func replace() {
        guard phase == .done, !isUnchanged else { return }
        let text = result
        closePanel()
        Task { await bridge.replaceSelection(with: text) }
    }

    func copyResult() {
        guard phase == .done else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        copied = true
    }

    func closePanel() {
        task?.cancel()
        task = nil
        panel.close()
        reset(phase: .idle)
    }

    private func reset(phase: Phase) {
        self.phase = phase
        original = ""
        output = ""
        result = ""
        segments = []
        copied = false
    }

    // MARK: - Settings & permissions

    func showSettings(tab: SettingsTab? = nil) {
        closePanel()
        settingsWindow.show(tab: tab)
    }

    func findUpdates() {
        showSettings(tab: .general)
        Task { await updater.find() }
    }

    func installUpdate() {
        if updater.isHomebrewInstall {
            showSettings(tab: .general)
        } else {
            updater.install()
        }
    }

    func requestAccessibility() {
        closePanel()
        Accessibility.request()
    }

    func refreshAccessibility() {
        let granted = Accessibility.isTrusted
        if granted != accessibilityGranted { accessibilityGranted = granted }
    }

    func apiKey(for provider: Provider) -> String {
        if let cached = apiKeys[provider.id] { return cached }
        let value = Keychain.read(provider.id) ?? ""
        apiKeys[provider.id] = value
        return value
    }

    func setAPIKey(_ value: String, for provider: Provider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard apiKey(for: provider) != trimmed else { return }
        apiKeys[provider.id] = trimmed
        Keychain.save(trimmed, for: provider.id)
    }

    func makeBackend(for provider: Provider) -> any LLMBackend {
        let model = preferences.model(for: provider)
        switch provider.kind {
        case .openAICompatible:
            var backend = OpenAICompatibleBackend(provider: provider, baseURL: preferences.baseURL(for: provider),
                                                  apiKey: apiKey(for: provider), model: model)
            if provider.signIn.contains(.nousPortal), NousOAuth.isSignedIn {
                backend.tokenProvider = { try await NousSession.shared.accessToken() }
            }
            return backend
        case .claudeCLI:
            return ClaudeCodeBackend(model: model, pathOverride: preferences.cliPath(for: provider))
        case .codexCLI:
            return CodexBackend(model: model, pathOverride: preferences.cliPath(for: provider))
        }
    }
}
