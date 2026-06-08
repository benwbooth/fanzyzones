import AppKit

/// Coordinate-system conversions — the single source of truth for the trickiest
/// part of the app.
///
/// Three coordinate spaces are in play:
///  - **Normalized**: a layout zone as a fraction of its display's work area.
///    Origin top-left, (0,0)=top-left … (1,1)=bottom-right. Resolution-independent.
///  - **Cocoa**: `NSScreen` global space. Origin bottom-left, Y grows *up*. The
///    primary display's origin is (0,0). Used for drawing overlay `NSWindow`s.
///  - **Accessibility (AX)**: the space `AXUIElement` position/size use. Origin
///    top-left, Y grows *down*, global, primary display's top-left at (0,0). Used
///    when moving other apps' windows.
enum Geometry {

    /// The primary display — the one whose Cocoa origin is (0,0). Its height is the
    /// reference used to flip between Cocoa (Y-up) and AX (Y-down) global spaces.
    static func primaryFrameHeight() -> CGFloat {
        for screen in NSScreen.screens where screen.frame.origin == .zero {
            return screen.frame.height
        }
        // Fallback: first screen. Should not happen in practice.
        return NSScreen.screens.first?.frame.height ?? 0
    }

    /// Convert a normalized zone rect into a Cocoa pixel rect inside `area`
    /// (typically a screen's `visibleFrame`), applying an outer `padding` around the
    /// whole area and a `gap` of empty space around each zone.
    ///
    /// `normalized` uses a top-left origin; the result is Cocoa (bottom-left origin).
    static func cocoaRect(forNormalized normalized: CGRect,
                          in area: CGRect,
                          padding: CGFloat = 0,
                          gap: CGFloat = 0) -> CGRect {
        let inner = area.insetBy(dx: padding, dy: padding)
        let x = inner.minX + normalized.minX * inner.width
        // Flip Y within the area: normalized top-left -> Cocoa bottom-left.
        let y = inner.minY + (1 - normalized.maxY) * inner.height
        let rect = CGRect(x: x,
                          y: y,
                          width: normalized.width * inner.width,
                          height: normalized.height * inner.height)
        return rect.insetBy(dx: gap / 2, dy: gap / 2)
    }

    /// Convert a Cocoa global rect (bottom-left origin, Y-up) into an AX global rect
    /// (top-left origin, Y-down) suitable for setting an `AXUIElement`'s frame.
    static func cocoaToAX(_ rect: CGRect) -> CGRect {
        let h = primaryFrameHeight()
        return CGRect(x: rect.origin.x,
                      y: h - rect.origin.y - rect.height,
                      width: rect.width,
                      height: rect.height)
    }

    /// Convert an AX global point (top-left origin, Y-down) into Cocoa global
    /// coordinates (bottom-left origin, Y-up). Used to map the mouse location the
    /// event tap reports into the space `NSScreen` works in.
    static func axPointToCocoa(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryFrameHeight() - point.y)
    }
}
