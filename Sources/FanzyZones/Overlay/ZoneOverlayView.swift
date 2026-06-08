import AppKit

/// Draws the active layout's zones as translucent rounded rectangles, with the
/// hovered zone highlighted. Lives inside a transparent, click-through overlay window.
final class ZoneOverlayView: NSView {
    struct Item {
        let rect: CGRect          // in this view's (bottom-left origin) coordinates
        let highlighted: Bool
        let number: Int           // 1-based zone number for the label
    }

    var items: [Item] = [] {
        didSet { needsDisplay = true }
    }

    /// Appearance, driven by user settings.
    var color: NSColor = .controlAccentColor
    var baseOpacity: CGFloat = 0.35
    var showNumbers: Bool = true

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let hoverFill = baseOpacity
        let idleFill = baseOpacity * 0.3
        let hoverStroke = min(baseOpacity * 2.6, 1.0)
        let idleStroke = min(baseOpacity * 1.3, 0.6)

        for item in items {
            let path = NSBezierPath(roundedRect: item.rect.insetBy(dx: 2, dy: 2),
                                    xRadius: 10, yRadius: 10)
            color.withAlphaComponent(item.highlighted ? hoverFill : idleFill).setFill()
            path.fill()
            color.withAlphaComponent(item.highlighted ? hoverStroke : idleStroke).setStroke()
            path.lineWidth = item.highlighted ? 4 : 1.5
            path.stroke()

            if showNumbers { drawNumber(item) }
        }
    }

    private func drawNumber(_ item: Item) {
        let size: CGFloat = min(item.rect.width, item.rect.height) > 120 ? 40 : 24
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(item.highlighted ? 0.95 : 0.55)
        ]
        let text = "\(item.number)" as NSString
        let textSize = text.size(withAttributes: attrs)
        let origin = CGPoint(x: item.rect.midX - textSize.width / 2,
                             y: item.rect.midY - textSize.height / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
}
