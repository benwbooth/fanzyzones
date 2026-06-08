import AppKit
import ApplicationServices

/// Turns a (zone, screen) into a concrete window move. Shared by the menu actions
/// and the drag engine so geometry/gaps behave identically everywhere.
@MainActor
final class SnapEngine {
    private let windowManager: WindowManager
    private let state: AppState

    init(windowManager: WindowManager, state: AppState) {
        self.windowManager = windowManager
        self.state = state
    }

    /// The Cocoa (bottom-left origin) pixel rect a zone occupies on a screen,
    /// honoring the configured gap and padding.
    func cocoaRect(for zone: Zone, on screen: NSScreen) -> CGRect {
        Geometry.cocoaRect(forNormalized: zone.rect,
                           in: screen.visibleFrame,
                           padding: state.settings.padding,
                           gap: state.settings.gap)
    }

    /// Snap a specific window element into a zone on a screen.
    @discardableResult
    func snap(window: AXUIElement, to zone: Zone, on screen: NSScreen) -> Bool {
        let cocoa = cocoaRect(for: zone, on: screen)
        return windowManager.setFrame(window, to: Geometry.cocoaToAX(cocoa))
    }

    /// Snap the frontmost window into a zone on a screen. Returns false (and beeps)
    /// if there's no focused window or permission is missing.
    @discardableResult
    func snapFocusedWindow(to zone: Zone, on screen: NSScreen) -> Bool {
        guard let window = windowManager.focusedWindow() else {
            NSSound.beep()
            return false
        }
        return snap(window: window, to: zone, on: screen)
    }

    // MARK: - Keyboard-driven snapping

    /// Snap the focused window to zone `index` of the layout active on the window's
    /// current display.
    @discardableResult
    func snapFocusedWindow(toZoneIndex index: Int) -> Bool {
        guard let window = windowManager.focusedWindow(),
              let screen = screen(for: window) else {
            NSSound.beep()
            return false
        }
        let layout = state.layout(forScreen: screen)
        guard index >= 0, index < layout.zones.count else {
            NSSound.beep()
            return false
        }
        return snap(window: window, to: layout.zones[index], on: screen)
    }

    /// Move the focused window to the next/previous zone (by `delta`, wrapping),
    /// starting from whichever zone its center is currently nearest, using the layout
    /// active on the window's display.
    @discardableResult
    func cycleFocusedWindow(by delta: Int) -> Bool {
        guard let window = windowManager.focusedWindow(),
              let screen = screen(for: window) else {
            NSSound.beep()
            return false
        }
        let layout = state.layout(forScreen: screen)
        guard !layout.zones.isEmpty else { NSSound.beep(); return false }
        let current = nearestZoneIndex(of: window, in: layout, on: screen) ?? 0
        let count = layout.zones.count
        let target = ((current + delta) % count + count) % count
        return snap(window: window, to: layout.zones[target], on: screen)
    }

    /// The screen a window currently sits on (by its center), falling back to main.
    func screen(for window: AXUIElement) -> NSScreen? {
        guard let axFrame = windowManager.frame(of: window) else { return NSScreen.main }
        let axCenter = CGPoint(x: axFrame.midX, y: axFrame.midY)
        let cocoaCenter = Geometry.axPointToCocoa(axCenter)
        return NSScreen.screens.first { $0.frame.contains(cocoaCenter) } ?? NSScreen.main
    }

    /// Index of the zone whose pixel center is closest to the window's center.
    private func nearestZoneIndex(of window: AXUIElement, in layout: Layout,
                                  on screen: NSScreen) -> Int? {
        guard let axFrame = windowManager.frame(of: window) else { return nil }
        let windowCenter = Geometry.axPointToCocoa(CGPoint(x: axFrame.midX, y: axFrame.midY))
        var best: (index: Int, distance: CGFloat)?
        for (i, zone) in layout.zones.enumerated() {
            let r = cocoaRect(for: zone, on: screen)
            let c = CGPoint(x: r.midX, y: r.midY)
            let d = hypot(c.x - windowCenter.x, c.y - windowCenter.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }
}
