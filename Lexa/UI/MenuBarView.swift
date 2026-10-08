import SwiftUI

struct MenuBarView: View {
    let state: AppState

    var body: some View {
        let hotKey = state.preferences.hotKey
        if let key = hotKey.keyEquivalent {
            Button("Check Selection") { state.checkSelection(fromMenu: true) }
                .keyboardShortcut(key, modifiers: hotKey.eventModifiers)
        } else {
            Button("Check Selection (\(hotKey.display))") { state.checkSelection(fromMenu: true) }
        }

        Divider()

        Text(state.providerSummary)
        if !state.accessibilityGranted {
            Button("Grant Accessibility Access…") { state.requestAccessibility() }
        }
        if !state.hotKeyRegistered {
            Text("Shortcut \(hotKey.display) is in use by another app")
        }

        Divider()

        Button("Settings…") { state.showSettings() }
            .keyboardShortcut(",")
        Button("Quit Lexa") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
            .onAppear { state.refreshAccessibility() }
    }
}
