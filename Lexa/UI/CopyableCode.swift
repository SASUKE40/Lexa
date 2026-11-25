import AppKit
import SwiftUI

/// A monospaced command or verification code inside a rounded badge with a copy button
/// that shows a temporary checkmark after you copy it.
struct CopyableCode: View {
    let text: String
    var font: Font = .callout.monospaced()
    var helpText = "Copy the command"

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(font)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help(copied ? "Copied" : helpText)
        }
        .onDisappear { resetTask?.cancel() }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
