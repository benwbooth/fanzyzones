import AppKit
import SwiftUI

/// Hosts the SwiftUI `EditorView` in a normal window. Because the app is an agent
/// (`LSUIElement`), we temporarily switch to a regular activation policy while the
/// editor is open so its text field and buttons receive focus, then switch back.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    /// Open the editor. Pass an existing layout to edit/duplicate, or nil for a new one.
    func show(editing layout: Layout?) {
        let aspect = mainScreenAspect()
        let view = EditorView(
            initial: layout,
            screenAspect: aspect,
            onSave: { [weak self] newLayout in
                self?.state.upsertCustomLayout(newLayout)
                self?.state.setActiveLayout(newLayout.id)
                self?.closeWindow()
            },
            onCancel: { [weak self] _ in self?.closeWindow() }
        )

        let hosting = NSHostingController(rootView: view)
        let window: NSWindow
        if let existing = self.window {
            existing.contentViewController = hosting
            window = existing
        } else {
            window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .resizable]
            window.title = "FanzyZones — Layout Editor"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(NSSize(width: 860, height: 620))
            self.window = window
        }

        NSApp.setActivationPolicy(.regular)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeWindow() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Return to menu-bar-only mode.
        NSApp.setActivationPolicy(.accessory)
    }

    private func mainScreenAspect() -> CGFloat {
        guard let frame = NSScreen.main?.visibleFrame, frame.height > 0 else { return 1.6 }
        return frame.width / frame.height
    }
}
