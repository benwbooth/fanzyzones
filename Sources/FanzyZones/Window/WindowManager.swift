import AppKit
import ApplicationServices

/// Reads and moves windows belonging to other applications via the Accessibility
/// API. All geometry passed in/out of here is in **AX coordinates** (top-left
/// origin) — use `Geometry.cocoaToAX` at the boundary.
@MainActor
final class WindowManager {

    /// The frontmost app's focused window, if any.
    func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return copyElement(appElement, attribute: kAXFocusedWindowAttribute)
    }

    /// The window under a given AX-space screen point, walking up from whatever UI
    /// element is hit to its containing window. Used by the drag engine later.
    func window(at axPoint: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(system,
                                                   Float(axPoint.x),
                                                   Float(axPoint.y),
                                                   &hit)
        guard err == .success, let element = hit else { return nil }
        return enclosingWindow(of: element)
    }

    /// Move and resize a window so it fills `axFrame` (AX coordinates).
    @discardableResult
    func setFrame(_ window: AXUIElement, to axFrame: CGRect) -> Bool {
        // Order matters subtly: set size, then position, then size again. Some apps
        // constrain position to the old size, or clamp size to the old position;
        // a size→position→size sequence settles both for the common cases.
        let okSize1 = setSize(window, axFrame.size)
        let okPos = setPosition(window, axFrame.origin)
        let okSize2 = setSize(window, axFrame.size)
        return okSize1 && okPos && okSize2
    }

    /// Current AX frame of a window, or nil if unreadable.
    func frame(of window: AXUIElement) -> CGRect? {
        guard let posValue = copyValue(window, attribute: kAXPositionAttribute),
              let sizeValue = copyValue(window, attribute: kAXSizeAttribute) else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue, .cgPoint, &point)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    // MARK: - Primitives

    private func setPosition(_ window: AXUIElement, _ point: CGPoint) -> Bool {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(window,
                                            kAXPositionAttribute as CFString,
                                            value) == .success
    }

    private func setSize(_ window: AXUIElement, _ size: CGSize) -> Bool {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return false }
        return AXUIElementSetAttributeValue(window,
                                            kAXSizeAttribute as CFString,
                                            value) == .success
    }

    private func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        // If the element is already a window, return it; otherwise climb via the
        // AXWindow attribute, falling back to walking parents.
        if role(of: element) == kAXWindowRole as String { return element }
        if let window = copyElement(element, attribute: kAXWindowAttribute) {
            return window
        }
        var current: AXUIElement? = element
        while let node = current {
            if role(of: node) == kAXWindowRole as String { return node }
            current = copyElement(node, attribute: kAXParentAttribute)
        }
        return nil
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            kAXRoleAttribute as CFString,
                                            &value) == .success else { return nil }
        return value as? String
    }

    private func copyElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            attribute as CFString,
                                            &value) == .success,
              let result = value,
              CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    private func copyValue(_ element: AXUIElement, attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            attribute as CFString,
                                            &value) == .success,
              let result = value,
              CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        return (result as! AXValue)
    }
}
