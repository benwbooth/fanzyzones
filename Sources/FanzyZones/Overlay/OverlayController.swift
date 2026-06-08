import AppKit

/// Shows the zone overlay during a drag. One transparent, click-through window per
/// screen is created lazily and reused; only the screen under the cursor is visible.
@MainActor
final class OverlayController {
    /// A zone to draw, in global Cocoa coordinates (bottom-left origin).
    struct ZoneRect {
        let id: Int
        let globalRect: CGRect
    }

    private var windowsByScreen: [CGDirectDisplayID: NSWindow] = [:]

    /// Visual appearance for the overlay, sourced from user settings.
    struct Appearance {
        let color: NSColor
        let opacity: CGFloat
        let showNumbers: Bool
    }

    /// Display the given zones on `screen`, highlighting `highlighted`. Hides
    /// overlays on every other screen.
    func show(on screen: NSScreen, zones: [ZoneRect], highlighted: Int?,
              appearance: Appearance) {
        let window = window(for: screen)
        guard let view = window.contentView as? ZoneOverlayView else { return }

        view.color = appearance.color
        view.baseOpacity = appearance.opacity
        view.showNumbers = appearance.showNumbers

        let origin = screen.frame.origin
        view.items = zones.enumerated().map { index, zone in
            ZoneOverlayView.Item(
                rect: zone.globalRect.offsetBy(dx: -origin.x, dy: -origin.y),
                highlighted: zone.id == highlighted,
                number: index + 1)
        }
        window.orderFrontRegardless()

        // Hide overlays belonging to other screens.
        let activeID = displayID(of: screen)
        for (id, win) in windowsByScreen where id != activeID {
            win.orderOut(nil)
        }
    }

    func hide() {
        for win in windowsByScreen.values { win.orderOut(nil) }
    }

    // MARK: - Window management

    private func window(for screen: NSScreen) -> NSWindow {
        let id = displayID(of: screen)
        if let existing = windowsByScreen[id] {
            existing.setFrame(screen.frame, display: false)
            existing.contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
            return existing
        }

        let window = NSWindow(contentRect: screen.frame,
                              styleMask: .borderless,
                              backing: .buffered,
                              defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = ZoneOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view

        windowsByScreen[id] = window
        return window
    }

    private func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
