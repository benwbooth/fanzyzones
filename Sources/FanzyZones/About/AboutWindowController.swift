import AppKit
import SwiftUI

/// A small custom About window. We don't bundle an .icns, so the standard About panel
/// can't show our icon — this draws `AppIcon` directly instead.
@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let hosting = NSHostingController(rootView: AboutView(version: version))

        let window: NSWindow
        if let existing = self.window {
            existing.contentViewController = hosting
            window = existing
        } else {
            window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = "About FanzyZones"
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

private struct AboutView: View {
    let version: String

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: AppIcon.make())
                .resizable()
                .interpolation(.high)
                .frame(width: 92, height: 92)

            Text("FanzyZones")
                .font(.system(size: 20, weight: .semibold))
            Text("Version \(version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Native window zone snapping for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 28)
        .frame(width: 320)
    }
}
