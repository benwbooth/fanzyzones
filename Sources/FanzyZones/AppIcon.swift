import AppKit

/// Draws the app icon at runtime (a rounded "zones" tile), so we don't need a bundled
/// asset catalog. Used for the Dock icon (shown while editor/settings are open) and
/// the standard About panel.
enum AppIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()

        // Background: rounded rect with a blue gradient.
        let bg = NSRect(origin: .zero, size: size).insetBy(dx: 26, dy: 26)
        let bgPath = NSBezierPath(roundedRect: bg, xRadius: 104, yRadius: 104)
        NSGradient(colors: [
            NSColor(srgbRed: 0.24, green: 0.58, blue: 1.0, alpha: 1),
            NSColor(srgbRed: 0.10, green: 0.36, blue: 0.95, alpha: 1)
        ])?.draw(in: bgPath, angle: -90)

        // Panes: a large left zone and two stacked right zones (the app's motif).
        let inset = bg.insetBy(dx: 78, dy: 78)
        let gap: CGFloat = 20
        let leftW = inset.width * 0.55 - gap / 2

        func pane(_ rect: NSRect, alpha: CGFloat) {
            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26).fill()
        }

        pane(NSRect(x: inset.minX, y: inset.minY, width: leftW, height: inset.height),
             alpha: 0.95)

        let rightX = inset.minX + leftW + gap
        let rightW = inset.maxX - rightX
        let rightH = (inset.height - gap) / 2
        pane(NSRect(x: rightX, y: inset.minY + rightH + gap, width: rightW, height: rightH),
             alpha: 0.95)
        pane(NSRect(x: rightX, y: inset.minY, width: rightW, height: rightH),
             alpha: 0.78)

        image.unlockFocus()
        return image
    }
}
