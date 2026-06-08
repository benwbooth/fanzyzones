import AppKit
import ApplicationServices

/// Tracks and requests the Accessibility (AX) permission the app needs to move
/// other apps' windows. Without it, every `AXUIElement` mutation silently fails.
@MainActor
final class AccessibilityGate {

    /// Whether this process is currently trusted for Accessibility.
    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompt the user, opening the System Settings Accessibility pane if not yet
    /// trusted. Returns the trust status at call time.
    @discardableResult
    func promptIfNeeded() -> Bool {
        // Literal value of `kAXTrustedCheckOptionPrompt` — referencing the global
        // CFString directly trips Swift 6 strict-concurrency (it's a mutable global).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open the Accessibility settings pane directly (for a "Grant…" menu item even
    /// when the one-shot prompt has already been shown this launch).
    func openSettingsPane() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private var pollTimer: Timer?

    /// Poll trust status until granted, then invoke `onGranted` on the main actor.
    /// Cheap and simple: TCC gives no notification when permission is granted.
    func waitForTrust(pollInterval: TimeInterval = 1.0,
                      onGranted: @escaping @MainActor () -> Void) {
        if isTrusted { onGranted(); return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isTrusted {
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil
                    onGranted()
                }
            }
        }
    }
}
