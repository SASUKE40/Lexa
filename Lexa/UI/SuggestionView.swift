import SwiftUI

struct SuggestionView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if state.hasSelection { actions }
            content
            if state.hasSelection { footer }
        }
        .padding(16)
        .frame(width: SuggestionPanelController.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.badge.checkmark")
                .foregroundStyle(.tint)
            Text("Lexa").font(.headline)
            Spacer()
            Text(state.providerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                state.closePanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(.cancelAction)
            .help("Close (Esc)")
        }
    }

    // MARK: - Actions

    private var actions: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                chip(.fix, shortcut: "1")
                chip(.improve, shortcut: "2")
                Menu {
                    ForEach(Tone.allCases) { tone in
                        Button(tone.title) { state.run(.tone(tone)) }
                    }
                } label: {
                    Label(toneTitle, systemImage: "theatermasks")
                }
                .menuStyle(.button)
                .modifier(ChipStyle(selected: isTone))
                .fixedSize()
                Menu {
                    ForEach(languages, id: \.self) { language in
                        Button(language) { state.run(.translate(language)) }
                    }
                } label: {
                    Label("Translate", systemImage: "globe")
                }
                .menuStyle(.button)
                .modifier(ChipStyle(selected: isTranslate))
                .fixedSize()
                Spacer(minLength: 0)
            }
            .controlSize(.small)
        }
    }

    private func chip(_ action: WritingAction, shortcut: KeyEquivalent) -> some View {
        Button {
            state.run(action)
        } label: {
            Label(action.title, systemImage: action.symbol)
        }
        .modifier(ChipStyle(selected: state.action == action && state.phase != .ready))
        .keyboardShortcut(shortcut, modifiers: .command)
    }

    private var isTone: Bool {
        if case .tone = state.action, state.phase != .ready { return true }
        return false
    }

    private var isTranslate: Bool {
        if case .translate = state.action, state.phase != .ready { return true }
        return false
    }

    private var toneTitle: String {
        if case .tone(let tone) = state.action, isTone { return tone.title }
        return "Tone"
    }

    private var languages: [String] {
        let preferred = state.preferences.translateLanguage
        return [preferred] + WritingAction.languages.filter { $0 != preferred }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle:
            EmptyView()
        case .needsAccessibility:
            message(
                "Lexa needs Accessibility access to read and replace the text you select.",
                systemImage: "hand.raised.fill", color: .orange
            ) {
                Button("Open System Settings") { state.requestAccessibility() }
                    .buttonStyle(.glassProminent)
            }
        case .noSelection:
            message(
                "Select some text in any app, then press \(state.preferences.hotKey.display).",
                systemImage: "text.cursor", color: .secondary
            ) { EmptyView() }
        case .ready:
            AutoHeightScroll {
                Text(state.original).foregroundStyle(.secondary)
            }
        case .working:
            if state.liveText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(state.provider.isCLI ? "Asking \(state.provider.name)…" : "Thinking…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            } else {
                AutoHeightScroll {
                    Text(state.liveText).foregroundStyle(.primary.opacity(0.8))
                }
            }
        case .done:
            if state.isUnchanged {
                Label("Looks good. No changes needed.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            } else if state.action.showsDiff, state.showChanges {
                AutoHeightScroll { DiffView(segments: state.segments) }
            } else {
                AutoHeightScroll { Text(state.result).textSelection(.enabled) }
            }
        case .failed(let error):
            message(error, systemImage: "exclamationmark.triangle.fill", color: .orange) {
                Button("Settings…") { state.showSettings() }
            }
        }
    }

    private func message(
        _ text: String, systemImage: String, color: Color, @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(color)
            }
            action()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if state.phase == .done, state.action.showsDiff, !state.isUnchanged {
                Button {
                    state.showChanges.toggle()
                } label: {
                    Image(systemName: state.showChanges ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(state.showChanges ? "Show result only" : "Show changes")
            }
            Spacer()
            if state.phase == .working {
                ProgressView().controlSize(.small)
            }
            Button(state.copied ? "Copied" : "Copy") { state.copyResult() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(state.phase != .done)
            Button("Retry") { state.retry() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.phase == .ready)
            Button("Replace") { state.replace() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(state.phase != .done || state.isUnchanged)
        }
        .buttonStyle(.glass)
    }
}

private struct ChipStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

/// Scroll view that hugs its content up to `maxHeight`.
struct AutoHeightScroll<Content: View>: View {
    var maxHeight: CGFloat = 300
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 24

    var body: some View {
        ScrollView {
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(height, 20), maxHeight))
    }
}
