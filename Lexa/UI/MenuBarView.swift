import SwiftUI

struct MenuBarView: View {
    let state: AppState

    var body: some View {
        let hotKey = state.preferences.hotKey
        if let key = hotKey.keyEquivalent {
            Button {
                state.checkSelection(fromMenu: true)
            } label: {
                Label("Use Lexa on Selected Text", systemImage: "sparkles")
            }
            .keyboardShortcut(key, modifiers: hotKey.eventModifiers)
        } else {
            Button {
                state.checkSelection(fromMenu: true)
            } label: {
                Label("Use Lexa on Selected Text (\(hotKey.display))", systemImage: "sparkles")
            }
        }

        Divider()

        Text(state.providerSummary)
        if state.usage.today.requests > 0 {
            Text("Today: \(UsageFormatting.tokens(state.usage.today.totalTokens)) tokens · \(UsageFormatting.cost(state.usage.today.costUSD))")
        }
        if !state.accessibilityGranted {
            Button {
                state.requestAccessibility()
            } label: {
                Label("Give Accessibility Access…", systemImage: "hand.raised")
            }
        }
        if !state.hotKeyRegistered {
            Text("Another app uses the \(hotKey.display) shortcut")
        }

        if let release = state.updater.available {
            Button {
                state.installUpdate()
            } label: {
                Label("Install Lexa \(release.version.description)…", systemImage: "arrow.down.circle")
            }
        }

        Divider()

        Text("Lexa \(AppInfo.version)")
        Button {
            state.findUpdates()
        } label: {
            Label("Find Updates…", systemImage: "arrow.triangle.2.circlepath")
        }
        Button {
            state.showSettings()
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",")
        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit Lexa", systemImage: "power")
        }
        .keyboardShortcut("q")
        .onAppear {
            state.refreshAccessibility()
            state.usage.refreshDay()
        }
    }
}
