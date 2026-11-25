import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os

/// Reads and replaces the selection in the frontmost app (including terminals such as
/// Ghostty, Terminal.app, iTerm2, WezTerm, and integrated editor terminals),
/// restoring the user's clipboard afterwards.
final class TextBridge {
    private static let log = Logger(subsystem: "com.sasuke40.lexa", category: "TextBridge")
    private static let nativeAXTerminalBundleIDs: Set<String> = [
        "com.mitchellh.ghostty",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
    ]

    private(set) var sourceApp: NSRunningApplication?

    func captureSelection() async -> String? {
        sourceApp = await resolveSourceApp()
        let pid = sourceApp?.processIdentifier
        let bundleID = sourceApp?.bundleIdentifier ?? "unknown"
        Self.log.info("captureSelection start app=\(bundleID, privacy: .public) pid=\(pid ?? -1)")

        // 1. For native terminals that implement AXSelectedText (Ghostty, Terminal.app, iTerm2),
        //    read the selection directly via Accessibility without fighting held hotkey modifiers
        //    or touching the clipboard.
        if let bundleID = sourceApp?.bundleIdentifier, Self.nativeAXTerminalBundleIDs.contains(bundleID),
           let axText = readSelectedTextViaAccessibility(pid: pid) {
            Self.log.info("captureSelection hit direct AX text len=\(axText.count)")
            return axText
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let before = pasteboard.changeCount

        // 2. Trigger the app's native Edit → Copy menu item via Accessibility.
        //    Works in Cocoa apps and terminals even while Option from ⌥⌘G is still held.
        if let pid, triggerMenuShortcut(pid: pid, cmdChar: "C") {
            if let text = await waitForClipboardText(pasteboard, after: before, attempts: 10, interval: .milliseconds(15)) {
                Self.log.info("captureSelection hit AX menu Copy len=\(text.count)")
                snapshot.restore(to: pasteboard)
                return text
            }
            Self.log.info("captureSelection AX menu Copy did not change clipboard")
        } else {
            Self.log.info("captureSelection AX menu Copy not triggered")
        }

        // 3. Wait for conflicting physical modifiers (⌥, ⌃, ⇧) from the hotkey to release,
        //    then send a full ⌘C key chord (with Command flagsChanged when needed).
        await waitForConflictingModifiersToRelease()
        await postCommandKey(CGKeyCode(kVK_ANSI_C))
        if let text = await waitForClipboardText(pasteboard, after: before, attempts: 20, interval: .milliseconds(18)) {
            Self.log.info("captureSelection hit synthetic Cmd+C len=\(text.count)")
            snapshot.restore(to: pasteboard)
            return text
        }

        // 4. Final fallback: read AXSelectedText directly from the focused element or its children.
        if let axText = readSelectedTextViaAccessibility(pid: pid) {
            Self.log.info("captureSelection hit fallback AX text len=\(axText.count)")
            return axText
        }

        Self.log.info("captureSelection returned nil for app=\(bundleID, privacy: .public)")
        return nil
    }

    func replaceSelection(with text: String) async {
        if let app = sourceApp {
            app.activate()
            await waitForActivation(pid: app.processIdentifier)
            try? await Task.sleep(for: .milliseconds(50))
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.writeObjects([item])

        await waitForConflictingModifiersToRelease(maxWait: .milliseconds(150))
        await postCommandKey(CGKeyCode(kVK_ANSI_V))

        try? await Task.sleep(for: .milliseconds(500))
        snapshot.restore(to: pasteboard)
    }

    // MARK: - App activation & clipboard polling

    private func resolveSourceApp() async -> NSRunningApplication? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for _ in 0..<15 {
            if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
                return front
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
        return NSWorkspace.shared.frontmostApplication
    }

    private func waitForActivation(pid: pid_t) async {
        for _ in 0..<16 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { return }
            try? await Task.sleep(for: .milliseconds(15))
        }
    }

    private func waitForClipboardText(
        _ pasteboard: NSPasteboard,
        after changeCount: Int,
        attempts: Int,
        interval: Duration
    ) async -> String? {
        for _ in 0..<attempts {
            try? await Task.sleep(for: interval)
            if pasteboard.changeCount != changeCount {
                return pasteboard.string(forType: .string)
            }
        }
        return nil
    }

    // MARK: - Synthetic key events

    nonisolated static let conflictingModifiers: CGEventFlags = [.maskAlternate, .maskControl, .maskShift]

    nonisolated static func hasConflictingModifiers(_ flags: CGEventFlags) -> Bool {
        !flags.intersection(conflictingModifiers).isEmpty
    }

    private func waitForConflictingModifiersToRelease(maxWait: Duration = .milliseconds(450)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + maxWait
        while clock.now < deadline {
            let flags = CGEventSource.flagsState(.hidSystemState)
            if !Self.hasConflictingModifiers(flags) { return }
            try? await Task.sleep(for: .milliseconds(15))
        }
    }

    private func postCommandKey(_ key: CGKeyCode) async {
        let hidFlags = CGEventSource.flagsState(.hidSystemState)
        let commandAlreadyHeld = hidFlags.contains(.maskCommand)
        let source = CGEventSource(stateID: .privateState)

        if !commandAlreadyHeld, let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(10))
        }
        if let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(for: .milliseconds(20))
        if let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }
        if !commandAlreadyHeld, let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            try? await Task.sleep(for: .milliseconds(10))
            cmdUp.flags = []
            cmdUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Accessibility helpers

    /// Finds a Command-only menu item (e.g. `⌘C` Copy) in the app's menu bar—
    /// independent of system language—and presses it.
    private func triggerMenuShortcut(pid: pid_t, cmdChar: String) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = axElement(app, kAXMenuBarAttribute),
              let menuBarItems = axElements(menuBar, kAXChildrenAttribute)
        else { return false }

        var fallbackItem: AXUIElement?
        for menuBarItem in menuBarItems {
            guard let submenus = axElements(menuBarItem, kAXChildrenAttribute),
                  let submenu = submenus.first,
                  let items = axElements(submenu, kAXChildrenAttribute)
            else { continue }

            for item in items {
                guard let key = axString(item, kAXMenuItemCmdCharAttribute),
                      key.caseInsensitiveCompare(cmdChar) == .orderedSame
                else { continue }
                let modifiers = axInt(item, kAXMenuItemCmdModifiersAttribute) ?? 0
                guard modifiers == 0 else { continue }
                if axBool(item, kAXEnabledAttribute) != false {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
                fallbackItem = fallbackItem ?? item
            }
        }
        // Some apps validate menu items lazily when opened; try pressing the matching item anyway.
        if let fallbackItem {
            return AXUIElementPerformAction(fallbackItem, kAXPressAction as CFString) == .success
        }
        return false
    }

    private func readSelectedTextViaAccessibility(pid: pid_t?) -> String? {
        var roots: [AXUIElement] = []
        if let pid {
            let app = AXUIElementCreateApplication(pid)
            if let focused = axElement(app, kAXFocusedUIElementAttribute) { roots.append(focused) }
            if let window = axElement(app, kAXFocusedWindowAttribute) { roots.append(window) }
        }
        if let focused = axElement(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) {
            roots.append(focused)
        }

        // BFS through focused element / focused window descendants (up to 40 nodes) so wrapped
        // terminal surfaces (e.g. AXScrollArea → AXTextArea in Ghostty) are reached reliably.
        var queue = roots
        var visited = 0
        while !queue.isEmpty, visited < 40 {
            let element = queue.removeFirst()
            visited += 1
            if let text = extractSelectedText(from: element) {
                return text
            }
            if let children = axElements(element, kAXChildrenAttribute), !children.isEmpty {
                queue.append(contentsOf: children.prefix(12))
            }
        }
        return nil
    }

    private func extractSelectedText(from element: AXUIElement) -> String? {
        if let selected = axString(element, kAXSelectedTextAttribute), !selected.isEmpty {
            return selected
        }
        if let value = axString(element, kAXValueAttribute),
           let range = axRange(element, kAXSelectedTextRangeAttribute),
           let slice = Self.sliceUTF16(value, location: range.location, length: range.length),
           !slice.isEmpty {
            return slice
        }
        return nil
    }

    private func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func axElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = axValue(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func axElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        guard let array = axValue(element, attribute) as? [AnyObject] else { return nil }
        return array.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? unsafeDowncast(item, to: AXUIElement.self) : nil
        }
    }

    private func axRange(_ element: AXUIElement, _ attribute: String) -> CFRange? {
        guard let value = axValue(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axVal) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(axVal, .cfRange, &range) ? range : nil
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        axValue(element, attribute) as? String
    }

    private func axBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        axValue(element, attribute) as? Bool
    }

    private func axInt(_ element: AXUIElement, _ attribute: String) -> Int? {
        (axValue(element, attribute) as? NSNumber).flatMap {
            CFGetTypeID($0) != CFBooleanGetTypeID() ? $0.intValue : nil
        }
    }

    nonisolated static func sliceUTF16(_ string: String, location: Int, length: Int) -> String? {
        guard location >= 0, length > 0 else { return nil }
        let ns = string as NSString
        guard location + length <= ns.length else { return nil }
        return ns.substring(with: NSRange(location: location, length: length))
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
