import AppKit
import ServiceManagement
import SwiftUI

final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(state: state)))
            window.title = "Lexa Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let state: AppState

    var body: some View {
        TabView {
            Tab("Provider", systemImage: "cpu") {
                ProviderSettingsView(state: state, preferences: state.preferences)
            }
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(state: state, preferences: state.preferences)
            }
        }
        .frame(width: 540, height: 600)
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
                Text(provider.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if provider.isCLI {
                subscriptionSection
            } else {
                apiSection
            }

            modelSection

            Section {
                HStack {
                    Button("Test Connection", action: test)
                        .disabled(isTesting)
                    if isTesting { ProgressView().controlSize(.small) }
                    Spacer()
                }
                if let status { StatusLabel(status: status) }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: preferences.providerID) { old, _ in
            state.setAPIKey(apiKey, for: Provider.with(id: old))
            load()
        }
        .task(id: apiKey) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            state.setAPIKey(apiKey, for: provider)
        }
        .onDisappear { state.setAPIKey(apiKey, for: provider) }
    }

    @ViewBuilder
    private var apiSection: some View {
        Section("Connection") {
            if provider.needsKey || provider.id == Provider.custom.id {
                SecureField("API Key", text: $apiKey, prompt: Text(provider.needsKey ? "Required" : "Optional"))
            }
            if provider.allowsBaseURLEdit {
                TextField("Base URL", text: binding(\.baseURLs, default: provider.baseURL),
                          prompt: Text("https://example.com/v1"))
            }
            if let url = provider.keyURL {
                Link(provider.needsKey ? "Get a free API key ↗" : "Download \(provider.name) ↗", destination: url)
            }
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        Section("Subscription") {
            LabeledContent("Sign in once in Terminal") {
                Text(provider.kind == .claudeCLI ? "claude auth login" : "codex login")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            TextField("CLI path", text: binding(\.cliPaths, default: ""), prompt: Text("Auto-detect"))
            if let url = provider.keyURL {
                Link("Install the \(provider.executable) CLI ↗", destination: url)
            }
            Text("Lexa runs your own signed-in CLI on this Mac and never reads its credentials. Intended for personal use under your plan's terms.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modelSection: some View {
        Section("Model") {
            TextField("Model", text: binding(\.models, default: provider.defaultModel),
                      prompt: Text(provider.isCLI ? "CLI default" : "model-id"))
            HStack {
                Menu("Choose") {
                    ForEach(modelChoices, id: \.self) { model in
                        Button(model) { preferences.models[provider.id] = model }
                    }
                }
                .fixedSize()
                .disabled(modelChoices.isEmpty)
                if !provider.isCLI {
                    Button("Fetch Models", action: fetchModels)
                        .disabled(isFetching)
                    if isFetching { ProgressView().controlSize(.small) }
                }
                Spacer()
                if fetchedModels.count > 0 {
                    Text("\(fetchedModels.count) available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
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

    private func load() {
        apiKey = state.apiKey(for: provider)
        fetchedModels = []
        status = nil
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
                status = fetchedModels.isEmpty ? .problem("No models returned.") : nil
            } catch {
                status = .problem(error.localizedDescription)
            }
            isFetching = false
        }
    }
}

private struct StatusLabel: View {
    let status: BackendStatus

    var body: some View {
        switch status {
        case .ready(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .problem(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .textSelection(.enabled)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    let state: AppState
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Check selection") {
                    HotKeyRecorder(state: state)
                }
                if !state.hotKeyRegistered {
                    Label("This shortcut is taken by another app. Pick a different one.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Behavior") {
                Picker("Default action", selection: $preferences.defaultActionID) {
                    ForEach(WritingAction.defaultChoices) { action in
                        Text(action.title).tag(action.id)
                    }
                    Text("Translate").tag(WritingAction.translate("").id)
                }
                Picker("Translate to", selection: $preferences.translateLanguage) {
                    ForEach(WritingAction.languages, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Run default action right away", isOn: $preferences.autoRun)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    if state.accessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") { state.requestAccessibility() }
                    }
                }
                Text("Used to copy your selected text and paste the result back. If you rebuild the app, you may need to toggle Lexa off and on again in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Your text is sent only to the provider you choose. Ollama and LM Studio keep it on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
        HStack {
            Button(isRecording ? "Type shortcut…" : state.preferences.hotKey.display) {
                isRecording ? stop() : start()
            }
            .frame(minWidth: 120)
            if state.preferences.hotKey != .default {
                Button("Reset") {
                    state.preferences.hotKey = .default
                    state.registerHotKey()
                }
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
