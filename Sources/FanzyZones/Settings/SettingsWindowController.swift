import AppKit
import SwiftUI

/// Hosts the SwiftUI `SettingsView` in a normal window, switching the agent app to a
/// regular activation policy while it's open (so controls take focus).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private let accessibility: AccessibilityGate
    private var window: NSWindow?

    init(state: AppState, accessibility: AccessibilityGate) {
        self.state = state
        self.accessibility = accessibility
    }

    func show() {
        let view = SettingsView(
            settings: state.settings,
            onChange: { [weak self] newSettings in
                self?.state.replaceSettings(newSettings)
            },
            onGrantAccessibility: { [weak self] in
                if self?.accessibility.promptIfNeeded() == false {
                    self?.accessibility.openSettingsPane()
                }
            },
            refreshTrust: { [weak self] in self?.accessibility.isTrusted ?? false }
        )

        let hosting = NSHostingController(rootView: view)
        let window: NSWindow
        if let existing = self.window {
            existing.contentViewController = hosting
            window = existing
        } else {
            window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = "FanzyZones Settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }

        NSApp.setActivationPolicy(.regular)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
