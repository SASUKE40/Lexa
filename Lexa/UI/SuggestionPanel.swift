import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus without activating Lexa,
/// so the app the user was typing in stays frontmost.
final class FloatingPanel: NSPanel {
    var onDismiss: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 160),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, !self.isKeyWindow else { return }
            self.onDismiss?()
        }
    }
}

/// Background layer that moves the window when you drag an empty part of the popup.
/// SwiftUI content does not pass drags to `isMovableByWindowBackground`, so this view starts the drag itself.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

final class SuggestionPanelController {
    private let panel = FloatingPanel()
    static let width: CGFloat = 460
    static let cornerRadius: CGFloat = 22

    init(state: AppState) {
        let root = SuggestionView(state: state)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                self?.resize(to: size)
            }
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        // Clip the window to the glass shape so the window shadow follows the rounded
        // corners instead of drawing a grey rectangle around them.
        let container = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.addSubview(hosting)
        hosting.frame = container.bounds
        panel.contentView = container
        panel.onDismiss = { [weak state] in state?.closePanel() }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        if !panel.isVisible {
            let mouse = NSEvent.mouseLocation
            let height = max(panel.frame.height, 120)
            var frame = NSRect(x: mouse.x - 24, y: mouse.y - 18 - height, width: Self.width, height: height)
            frame = clamp(frame, near: mouse)
            panel.setFrame(frame, display: false)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    /// Grows/shrinks downward from the top edge as content changes.
    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size = NSSize(width: ceil(size.width), height: ceil(size.height))
        frame.origin.y = top - frame.height
        frame = clamp(frame, near: NSPoint(x: frame.midX, y: top))
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func clamp(_ frame: NSRect, near point: NSPoint) -> NSRect {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var frame = frame
        frame.origin.x = min(max(frame.minX, visible.minX + 8), visible.maxX - frame.width - 8)
        if frame.minY < visible.minY + 8 { frame.origin.y = visible.minY + 8 }
        if frame.maxY > visible.maxY - 8 { frame.origin.y = visible.maxY - 8 - frame.height }
        return frame
    }
}
