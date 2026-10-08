import AppKit
import ServiceManagement
import SwiftUI

/// Native preferences window: toolbar tabs, sized to its content.
final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil {
            let tabs = SettingsTabViewController()
            tabs.tabStyle = .toolbar
            tabs.addTab("Provider", symbol: "sparkles", ProviderSettingsView(state: state, preferences: state.preferences))
            tabs.addTab("General", symbol: "gearshape", GeneralSettingsView(state: state, preferences: state.preferences))
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private final class SettingsTabViewController: NSTabViewController {
    func addTab(_ title: String, symbol: String, _ view: some View) {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }

    /// Keeps the window hugging the selected tab as its content changes (e.g. switching provider).
    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        guard tabViewItems.indices.contains(selectedTabViewItemIndex),
              tabViewItems[selectedTabViewItemIndex].viewController === viewController,
              let window = view.window
        else { return }
        let size = viewController.preferredContentSize
        guard size.width > 0, size.height > 0 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

private extension View {
    func settingsPage() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .frame(width: 480)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Provider

private struct ProviderSettingsView: View {
    let state: AppState
    @Bindable var preferences: Preferences
    @State private var apiKey = ""
    @State private var fetchedModels: [String] = []
    @State private var status: BackendStatus?
    @State private var isTesting = false
    @State private var isFetching = false
    /// nil while searching, "" when not found.
    @State private var detectedCLI: String?

    private var provider: Provider { preferences.provider }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $preferences.providerID) {
                    ForEach(ProviderGroup.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(Provider.all.filter { $0.group == group }) { provider in
                                Text(provider.name).tag(provider.id)
                            }
                        }
                    }
                }
            } footer: {
                Footer(provider.note)
            }

            if provider.isCLI {
                subscriptionSection
            } else {
                accountSection
            }
            modelSection
            testSection
        }
        .settingsPage()
        .onAppear(perform: load)
        .onChange(of: preferences.providerID) { old, _ in
            state.setAPIKey(apiKey, for: Provider.with(id: old))
            load()
        }
        .onChange(of: preferences.model(for: provider)) { status = nil }
        .task(id: apiKey) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            state.setAPIKey(apiKey, for: provider)
        }
        .task(id: "\(provider.id)|\(preferences.cliPath(for: provider))") {
            guard provider.isCLI else { return }
            detectedCLI = nil
            detectedCLI = await CLILocator.locate(provider.executable, override: preferences.cliPath(for: provider))?.path ?? ""
        }
        .onDisappear { state.setAPIKey(apiKey, for: provider) }
    }

    // MARK: Sections

    @ViewBuilder
    private var accountSection: some View {
        let showsKey = provider.needsKey || provider.id == Provider.custom.id
        if showsKey || provider.allowsBaseURLEdit {
            Section {
                if showsKey {
                    SecureField("API Key", text: $apiKey, prompt: Text(provider.needsKey ? "Paste your key" : "Optional"))
                }
                if provider.allowsBaseURLEdit {
                    TextField("Base URL", text: binding(\.baseURLs, default: provider.baseURL),
                              prompt: Text("https://example.com/v1"))
                }
            } header: {
                Text("Account")
            } footer: {
                if let url = provider.keyURL {
                    Link(provider.needsKey ? "Get a free API key ↗" : "Download \(provider.name) ↗", destination: url)
                        .font(.callout)
                }
            }
        }
    }

    private var subscriptionSection: some View {
        Section {
            LabeledContent("Sign in") {
                HStack(spacing: 6) {
                    Text(signInCommand)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(signInCommand, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy command")
                }
            }
            LabeledContent("Command-line tool") {
                HStack(spacing: 8) {
                    switch detectedCLI {
                    case nil:
                        ProgressView().controlSize(.small)
                    case "":
                        Label("Not found", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case let path?:
                        Text(abbreviate(path))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .help(path)
                    }
                    Button("Choose…", action: chooseCLI)
                    if !preferences.cliPath(for: provider).isEmpty {
                        Button("Reset") { preferences.cliPaths[provider.id] = nil }
                    }
                }
            }
        } header: {
            Text("Account")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Footer("Lexa runs your own signed-in \(provider.executable) CLI on this Mac and never reads its credentials. For personal use under your plan's terms.")
                if let url = provider.keyURL {
                    Link("Install the \(provider.executable) CLI ↗", destination: url).font(.callout)
                }
            }
        }
    }

    private var modelSection: some View {
        Section {
            LabeledContent("Model") {
                HStack(spacing: 4) {
                    TextField("Model", text: binding(\.models, default: provider.defaultModel),
                              prompt: Text(provider.isCLI ? "Default" : "model-id"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                    Menu {
                        ForEach(modelChoices, id: \.self) { model in
                            Button(model) { preferences.models[provider.id] = model }
                        }
                        if !provider.isCLI {
                            if !modelChoices.isEmpty { Divider() }
                            Button(isFetching ? "Fetching…" : "Fetch Available Models", action: fetchModels)
                                .disabled(isFetching)
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Choose a model")
                }
            }
        } header: {
            Text("Model")
        } footer: {
            if provider.isCLI {
                Footer("Leave empty to use the CLI's default model.")
            } else if isFetching {
                Footer("Fetching models…")
            } else if !fetchedModels.isEmpty {
                Footer("\(fetchedModels.count) models available. Pick one from the menu.")
            }
        }
    }

    private var testSection: some View {
        Section {
            HStack(spacing: 10) {
                switch status {
                case nil:
                    Text(isTesting ? "Testing…" : "Not tested yet")
                        .foregroundStyle(.secondary)
                case .ready(let message):
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                case .problem(let message):
                    Label {
                        Text(message).textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 8)
                if isTesting { ProgressView().controlSize(.small) }
                Button("Test Connection", action: test)
                    .disabled(isTesting)
            }
        }
    }

    // MARK: Helpers

    private var signInCommand: String {
        provider.kind == .claudeCLI ? "claude auth login" : "codex login"
    }

    private var modelChoices: [String] {
        var seen = Set<String>()
        return (provider.suggestedModels + fetchedModels).filter { seen.insert($0).inserted }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<Preferences, [String: String]>, default value: String) -> Binding<String> {
        let id = provider.id
        return Binding(
            get: { preferences[keyPath: keyPath][id] ?? value },
            set: { preferences[keyPath: keyPath][id] = $0 }
        )
    }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func load() {
        apiKey = state.apiKey(for: provider)
        fetchedModels = []
        status = nil
    }

    private func chooseCLI() {
        let panel = NSOpenPanel()
        panel.title = "Choose the \(provider.executable) executable"
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            preferences.cliPaths[provider.id] = url.path
        }
    }

    private func test() {
        state.setAPIKey(apiKey, for: provider)
        let backend = state.makeBackend(for: provider)
        isTesting = true
        status = nil
        Task {
            status = await backend.test()
            isTesting = false
        }
    }

    private func fetchModels() {
        state.setAPIKey(apiKey, for: provider)
        let backend = state.makeBackend(for: provider)
        isFetching = true
        Task {
            do {
                fetchedModels = try await backend.listModels()
                if fetchedModels.isEmpty { status = .problem("No models returned.") }
            } catch {
                status = .problem(error.localizedDescription)
            }
            isFetching = false
        }
    }
}

private struct Footer: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    let state: AppState
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                LabeledContent("Check selection") {
                    HotKeyRecorder(state: state)
                }
            } header: {
                Text("Shortcut")
            } footer: {
                if !state.hotKeyRegistered {
                    Label("This shortcut is taken by another app. Pick a different one.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("Writing") {
                Picker("Default action", selection: $preferences.defaultActionID) {
                    ForEach(WritingAction.defaultChoices) { action in
                        Text(action.title).tag(action.id)
                    }
                    Text("Translate").tag(WritingAction.translate("").id)
                }
                Picker("Translate to", selection: $preferences.translateLanguage) {
                    ForEach(WritingAction.languages, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Run default action immediately", isOn: $preferences.autoRun)
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Accessibility") {
                    if state.accessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") { state.requestAccessibility() }
                    }
                }
            } header: {
                Text("System")
            } footer: {
                Footer("Accessibility lets Lexa copy your selection and paste the result. Your text is sent only to the provider you choose.")
            }
        }
        .settingsPage()
        .task {
            while !Task.isCancelled {
                state.refreshAccessibility()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct HotKeyRecorder: View {
    let state: AppState
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stop() : start()
            } label: {
                Text(isRecording ? "Press keys…" : state.preferences.hotKey.display)
                    .font(.body.monospaced())
                    .frame(minWidth: 90)
            }
            .help(isRecording ? "Press a shortcut, or Esc to cancel" : "Click to change")
            if state.preferences.hotKey != .default, !isRecording {
                Button {
                    state.preferences.hotKey = .default
                    state.registerHotKey()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to \(HotKeyCombo.default.display)")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        state.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stop()
            } else if let combo = HotKeyCombo(event: event) {
                state.preferences.hotKey = combo
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording {
            isRecording = false
            state.registerHotKey()
        }
    }
}
