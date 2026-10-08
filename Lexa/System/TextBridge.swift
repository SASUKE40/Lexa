import AppKit
import Carbon.HIToolbox

/// Reads and replaces the selection in the frontmost app by simulating ⌘C / ⌘V,
/// restoring the user's clipboard afterwards.
final class TextBridge {
    private(set) var sourceApp: NSRunningApplication?

    func captureSelection() async -> String? {
        sourceApp = NSWorkspace.shared.frontmostApplication
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let before = pasteboard.changeCount

        postKey(CGKeyCode(kVK_ANSI_C))
        var text: String?
        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(20))
            if pasteboard.changeCount != before {
                text = pasteboard.string(forType: .string)
                break
            }
        }
        if pasteboard.changeCount != before { snapshot.restore(to: pasteboard) }
        return text
    }

    func replaceSelection(with text: String) async {
        sourceApp?.activate()
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.writeObjects([item])

        try? await Task.sleep(for: .milliseconds(80))
        postKey(CGKeyCode(kVK_ANSI_V))
        try? await Task.sleep(for: .milliseconds(500))
        snapshot.restore(to: pasteboard)
    }

    private func postKey(_ key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}

private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { entry[type] = data }
            }
            return entry
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        })
    }
}
