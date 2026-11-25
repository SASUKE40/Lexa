import SwiftUI

struct SuggestionView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if state.hasSelection { actions }
            contentCard
            if state.hasSelection { footer }
        }
        .padding(16)
        .frame(width: SuggestionPanelController.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.snappy(duration: 0.18), value: state.phase)
        .animation(.snappy(duration: 0.18), value: state.showChanges)
        .background(WindowDragArea())
        .glassEffect(.regular, in: .rect(cornerRadius: SuggestionPanelController.cornerRadius, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Group {
                Image(systemName: "text.badge.checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                Text("Lexa")
                    .font(.headline)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    ModelLogo(modelID: state.model, providerID: state.provider.id, size: 15)
                    Text(state.providerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.06), in: Capsule())
            }
            // Clicks go through to the drag area, so the full header moves the window.
            .allowsHitTesting(false)
            CloseButton { state.closePanel() }
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
                        Button {
                            state.run(.tone(tone))
                        } label: {
                            if state.action == .tone(tone), isTone {
                                Label(tone.title, systemImage: "checkmark")
                            } else {
                                Text(tone.title)
                            }
                        }
                    }
                } label: {
                    Label(toneTitle, systemImage: "theatermasks")
                }
                .menuStyle(.button)
                .modifier(ChipStyle(selected: isTone))
                .fixedSize()
                Menu {
                    ForEach(languages, id: \.self) { language in
                        Button {
                            state.run(.translate(language))
                        } label: {
                            if state.action == .translate(language), isTranslate {
                                Label(language, systemImage: "checkmark")
                            } else {
                                Text(language)
                            }
                        }
                    }
                } label: {
                    Label(translateTitle, systemImage: "globe")
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
        .help(action.help)
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

    private var translateTitle: String {
        if case .translate(let language) = state.action, isTranslate { return language }
        return "Translate"
    }

    private var languages: [String] {
        let preferred = state.preferences.translateLanguage
        return [preferred] + WritingAction.languages.filter { $0 != preferred }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentCard: some View {
        if state.phase != .idle {
            VStack(alignment: .leading, spacing: 10) {
                content
                if state.phase == .done, let usage = state.lastUsage {
                    Divider()
                        .opacity(0.5)
                    usageStrip(usage)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func usageStrip(_ usage: TokenUsage) -> some View {
        HStack(spacing: 8) {
            Label(
                "\(UsageFormatting.tokens(usage.inputTokens)) in · \(UsageFormatting.tokens(usage.outputTokens)) out",
                systemImage: "arrow.left.arrow.right"
            )
            Spacer(minLength: 8)
            if let cost = usage.costUSD {
                Text(UsageFormatting.cost(cost))
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .help(usage.detailTooltip)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle:
            EmptyView()
        case .needsAccessibility:
            message(
                "Lexa must have Accessibility access to read and replace the text that you select.",
                systemImage: "hand.raised.fill", color: .orange
            ) {
                Button("Open System Settings") { state.requestAccessibility() }
                    .buttonStyle(.glassProminent)
            }
        case .noSelection:
            message(
                "Select text in an app. Then press \(state.preferences.hotKey.display).",
                systemImage: "text.cursor", color: .secondary
            ) {
                if let clip = state.clipboardCandidate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or use the text on the clipboard:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(clip.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Button("Use Clipboard") { state.useClipboard() }
                            .buttonStyle(.glassProminent)
                            .keyboardShortcut(.defaultAction)
                            .help("Use Clipboard (↩)")
                    }
                }
            }
        case .ready:
            AutoHeightScroll {
                Text(state.original)
                    .font(.system(size: 13.5))
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
            }
        case .working:
            if state.liveText.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Lexa sent the text to \(state.provider.isCLI ? state.provider.name : "the model"). Wait for the result.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            } else {
                AutoHeightScroll {
                    Text(state.liveText)
                        .font(.system(size: 13.5))
                        .lineSpacing(4)
                        .foregroundStyle(.primary.opacity(0.85))
                }
            }
        case .done:
            if state.isUnchanged {
                Label("The text is correct. No changes are necessary.", systemImage: "checkmark.seal.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            } else if state.action.showsDiff, state.showChanges {
                AutoHeightScroll { DiffView(segments: state.segments) }
            } else {
                AutoHeightScroll {
                    Text(state.result)
                        .font(.system(size: 13.5))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
        case .failed(let error):
            message(error, systemImage: "exclamationmark.triangle.fill", color: .orange) {
                Button("Settings…") { state.showSettings() }
                    .buttonStyle(.glass)
            }
        }
    }

    private func message(
        _ text: String, systemImage: String, color: Color, @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .padding(.top, 1)
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
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
                    Label(state.showChanges ? "Changes" : "Result",
                          systemImage: state.showChanges ? "text.line.first.and.arrowtriangle.forward" : "doc.plaintext")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(state.showChanges ? "Show only the result" : "Show the changes")
            }
            Spacer()
            if state.phase == .working {
                ProgressView().controlSize(.small)
            }
            Button {
                state.copyResult()
            } label: {
                if state.copied {
                    Label("Copied", systemImage: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Text("Copy")
                }
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(state.phase != .done)
            .help("Copy (⌘C)")

            Button("Try Again") { state.retry() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.phase == .ready)
                .help("Try Again (⌘R)")

            Button("Replace") { state.replace() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(state.phase != .done || state.isUnchanged)
                .help("Replace (↩)")
        }
        .buttonStyle(.glass)
    }
}

private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(Color.primary.opacity(isHovered ? 0.1 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
