import AppKit

/// A visual menu row for one layout: a name/label region on the left and a scaled
/// diagram of the layout's panes on the right.
///
///  - Click a **pane** in the diagram → snap the focused window into that pane.
///  - Click the **name** region → make this the active layout (used by shift-drag).
///
/// Hovering highlights whichever region/pane is under the cursor.
final class LayoutMenuItemView: NSView {
    private let layout: Layout
    private var isActive: Bool
    private let onSnap: (_ layoutId: String, _ zoneId: Int) -> Void
    private let onSetActive: (_ layoutId: String) -> Void
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?

    private var hoveredZoneId: Int?
    private var hoveringLabel = false
    private var hoveringEdit = false
    private var hoveringDelete = false

    /// Marquee state: when the name is too long to fit, hovering the label scrolls
    /// it so the full name is readable (native tooltips don't show reliably inside
    /// an NSMenu, so we scroll instead).
    private var marqueeTimer: Timer?
    private var marqueeOffset: CGFloat = 0
    private let marqueeGap: CGFloat = 28

    private let padding: CGFloat = 8
    private let labelWidth: CGFloat = 150
    private let paneGap: CGFloat = 2

    static let itemSize = NSSize(width: 314, height: 92)

    init(layout: Layout,
         isActive: Bool,
         onSnap: @escaping (_ layoutId: String, _ zoneId: Int) -> Void,
         onSetActive: @escaping (_ layoutId: String) -> Void,
         onEdit: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.layout = layout
        self.isActive = isActive
        self.onSnap = onSnap
        self.onSetActive = onSetActive
        self.onEdit = onEdit
        self.onDelete = onDelete
        super.init(frame: NSRect(origin: .zero, size: Self.itemSize))
        toolTip = layout.name   // fallback for environments where it does show
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }   // top-left origin matches normalized zones

    // MARK: - Name metrics

    private var nameFont: NSFont {
        NSFont.systemFont(ofSize: 12, weight: isActive ? .semibold : .regular)
    }

    /// Width available to the name inside the label region.
    private var nameAvailableWidth: CGFloat { labelWidth - 4 }

    private var fullNameWidth: CGFloat {
        (layout.name as NSString).size(withAttributes: [.font: nameFont]).width
    }

    private var nameIsTruncated: Bool { fullNameWidth > nameAvailableWidth }

    // MARK: - Geometry

    private var labelRect: CGRect {
        CGRect(x: padding, y: padding,
               width: labelWidth, height: bounds.height - 2 * padding)
    }

    private var diagramRect: CGRect {
        let x = padding + labelWidth + padding
        return CGRect(x: x, y: padding,
                      width: bounds.width - x - padding,
                      height: bounds.height - 2 * padding)
    }

    private func rect(for zone: Zone) -> CGRect {
        let d = diagramRect
        let r = CGRect(x: d.minX + zone.rect.minX * d.width,
                       y: d.minY + zone.rect.minY * d.height,
                       width: zone.rect.width * d.width,
                       height: zone.rect.height * d.height)
        return r.insetBy(dx: paneGap, dy: paneGap)
    }

    private var editRect: CGRect {
        guard onEdit != nil else { return .zero }
        return CGRect(x: labelRect.minX + 2, y: labelRect.maxY - 16, width: 30, height: 15)
    }

    private var deleteRect: CGRect {
        guard onDelete != nil else { return .zero }
        let x = onEdit != nil ? editRect.maxX + 10 : labelRect.minX + 2
        return CGRect(x: x, y: labelRect.maxY - 16, width: 44, height: 15)
    }

    private func zone(at point: CGPoint) -> Zone? {
        layout.zones.first { rect(for: $0).contains(point) }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let accent = NSColor.controlAccentColor

        // Label hover background.
        if hoveringLabel {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: labelRect.insetBy(dx: -2, dy: 0),
                         xRadius: 5, yRadius: 5).fill()
        }

        // Name + active badge. The name sits on top with the badge on its own line
        // below it. The wider label fits most names; when one is still too long,
        // hovering scrolls it (marquee) so the full name is readable.
        let nameRect = CGRect(x: labelRect.minX + 2, y: labelRect.minY,
                              width: nameAvailableWidth, height: 30)
        if hoveringLabel && nameIsTruncated {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byClipping
            let attrs: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]
            let span = fullNameWidth + marqueeGap
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: nameRect).addClip()
            // Draw two copies so the scroll loops seamlessly.
            (layout.name as NSString).draw(
                at: CGPoint(x: nameRect.minX - marqueeOffset, y: nameRect.minY),
                withAttributes: attrs)
            (layout.name as NSString).draw(
                at: CGPoint(x: nameRect.minX - marqueeOffset + span, y: nameRect.minY),
                withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]
            (layout.name as NSString).draw(in: nameRect, withAttributes: attrs)
        }

        // Only the active layout shows a badge; "set default" is implied by clicking.
        if isActive {
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: accent
            ]
            ("✓ Active" as NSString).draw(
                at: CGPoint(x: labelRect.minX + 2, y: labelRect.minY + 33),
                withAttributes: badgeAttrs)
        }

        // Edit / Delete actions for custom layouts.
        if onEdit != nil {
            drawAction("Edit", in: editRect, hovered: hoveringEdit,
                       color: hoveringEdit ? accent : .secondaryLabelColor)
        }
        if onDelete != nil {
            drawAction("Delete", in: deleteRect, hovered: hoveringDelete,
                       color: hoveringDelete ? .systemRed : .secondaryLabelColor)
        }

        // Diagram frame (accent when active).
        let frame = NSBezierPath(roundedRect: diagramRect, xRadius: 6, yRadius: 6)
        (isActive ? accent.withAlphaComponent(0.7)
                  : NSColor.separatorColor).setStroke()
        frame.lineWidth = isActive ? 1.5 : 1
        frame.stroke()

        // Panes.
        for zone in layout.zones {
            let r = rect(for: zone)
            let path = NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3)
            let hovered = zone.id == hoveredZoneId
            accent.withAlphaComponent(hovered ? 0.55 : 0.18).setFill()
            path.fill()
            accent.withAlphaComponent(hovered ? 0.95 : 0.4).setStroke()
            path.lineWidth = hovered ? 2 : 1
            path.stroke()
        }
    }

    private func drawAction(_ text: String, in rect: CGRect, hovered: Bool,
                            color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: hovered ? .semibold : .regular),
            .foregroundColor: color
        ]
        (text as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY), withAttributes: attrs)
    }

    // MARK: - Tracking & clicks

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) { updateHover(event) }
    override func mouseEntered(with event: NSEvent) { updateHover(event) }

    override func mouseExited(with event: NSEvent) {
        hoveredZoneId = nil
        hoveringLabel = false
        hoveringEdit = false
        hoveringDelete = false
        stopMarquee()
        needsDisplay = true
    }

    /// Stop the marquee when the menu closes (the view leaves its window) so the
    /// repeating timer doesn't keep the view alive.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopMarquee() }
    }

    private func updateHover(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newEdit = onEdit != nil && editRect.contains(point)
        let newDelete = onDelete != nil && deleteRect.contains(point)
        let newZone = zone(at: point)?.id
        // The label region excludes the action hit-areas so they don't double-trigger.
        let newLabel = labelRect.contains(point) && !newEdit && !newDelete
        if newZone != hoveredZoneId || newLabel != hoveringLabel
            || newEdit != hoveringEdit || newDelete != hoveringDelete {
            hoveredZoneId = newZone
            hoveringLabel = newLabel
            hoveringEdit = newEdit
            hoveringDelete = newDelete
            if newLabel && nameIsTruncated { startMarquee() } else { stopMarquee() }
            needsDisplay = true
        }
    }

    // MARK: - Marquee

    private func startMarquee() {
        guard marqueeTimer == nil else { return }
        marqueeOffset = 0
        // Add to .common modes so it animates during the menu's tracking run loop.
        let timer = Timer(timeInterval: 0.03, target: self,
                          selector: #selector(stepMarquee), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .common)
        marqueeTimer = timer
    }

    private func stopMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
        if marqueeOffset != 0 { marqueeOffset = 0; needsDisplay = true }
    }

    @objc private func stepMarquee() {
        marqueeOffset += 1
        if marqueeOffset >= fullNameWidth + marqueeGap { marqueeOffset = 0 }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if onEdit != nil, editRect.contains(point) {
            dismissMenu()
            onEdit?()
        } else if onDelete != nil, deleteRect.contains(point) {
            dismissMenu()
            onDelete?()
        } else if let zone = zone(at: point) {
            dismissMenu()
            onSnap(layout.id, zone.id)
        } else if labelRect.contains(point) {
            dismissMenu()
            onSetActive(layout.id)
        }
    }

    private func dismissMenu() {
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
