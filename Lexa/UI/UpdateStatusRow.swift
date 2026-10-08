import AppKit
import SwiftUI

/// Update status and actions for Settings → General.
struct UpdateStatusRow: View {
    let updater: Updater

    var body: some View {
        switch updater.status {
        case .idle, .upToDate:
            HStack {
                Text(updater.status == .upToDate ? "You have the newest version." : "Lexa did not look for updates yet.")
                    .foregroundStyle(.secondary)
                Spacer()
                findButton
            }
        case .finding:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Lexa looks for updates. Wait.").foregroundStyle(.secondary)
                Spacer()
            }
        case .available(let release):
            HStack {
                Label("Lexa \(release.version.description) is available.", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.tint)
                Spacer()
                Link("Release Notes ↗", destination: release.pageURL)
            }
            if updater.isHomebrewInstall {
                LabeledContent("Homebrew") {
                    HStack(spacing: 6) {
                        Text(UpdateInstaller.brewCommand)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(UpdateInstaller.brewCommand, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy the command")
                    }
                }
                Text("You installed Lexa with Homebrew. To update Lexa, type this command in Terminal.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Spacer()
                    Button("Install the Update") { updater.install() }
                        .buttonStyle(.borderedProminent)
                }
            }
        case .installing(let release):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Lexa downloads and installs version \(release.version.description). Then Lexa starts again.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        case .failed(let message):
            HStack {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                Spacer()
                Button("Release Page") { updater.openReleasePage() }
                findButton
            }
        }
    }

    private var findButton: some View {
        Button("Find Updates") { Task { await updater.find() } }
    }
}
