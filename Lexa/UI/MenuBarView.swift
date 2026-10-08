import SwiftUI

struct MenuBarView: View {
    let state: AppState

    var body: some View {
        let hotKey = state.preferences.hotKey
        if let key = hotKey.keyEquivalent {
            Button("Use Lexa on Selected Text") { state.checkSelection(fromMenu: true) }
                .keyboardShortcut(key, modifiers: hotKey.eventModifiers)
        } else {
            Button("Use Lexa on Selected Text (\(hotKey.display))") { state.checkSelection(fromMenu: true) }
        }

        Divider()

        Text(state.providerSummary)
        if !state.accessibilityGranted {
            Button("Give Accessibility Access…") { state.requestAccessibility() }
        }
        if !state.hotKeyRegistered {
            Text("Another app uses the \(hotKey.display) shortcut")
        }

        if let release = state.updater.available {
            Button("Install Lexa \(release.version.description)…") { state.installUpdate() }
        }

        Divider()

        Text("Lexa \(AppInfo.version)")
        Button("Find Updates…") { state.findUpdates() }
        Button("Settings…") { state.showSettings() }
            .keyboardShortcut(",")
        Button("Quit Lexa") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
            .onAppear { state.refreshAccessibility() }
    }
}
