import AppKit
import ApplicationServices

/// Watches global mouse events to drive drag-to-snap. A passive (listen-only)
/// `CGEventTap` on the main run loop reports drags; while engaged we show the zone
/// overlay and, on mouse-up, snap the dragged window into the hovered zone.
///
/// Engagement depends on the snap mode:
///  - `.auto`     — engaged whenever a window is dragged.
///  - `.modifier` — engaged only while the configured modifier(s) are held.
@MainActor
final class DragMonitor {
    private let state: AppState
    private let snapEngine: SnapEngine
    private let windowManager: WindowManager
    private let overlay: OverlayController

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Per-drag state.
    private var mouseDown = false
    private var dragging = false
    private var engaged = false
    private var draggedWindow: AXUIElement?
    private var currentScreen: NSScreen?
    private var hoveredZoneId: Int?
    private var lastFlags: CGEventFlags = []

    /// The window under the cursor when the drag began, and where it started — used
    /// to tell a real window move apart from an in-app drag (text selection, sliders).
    private var candidateWindow: AXUIElement?
    private var startWindowOrigin: CGPoint?
    private var windowMoving = false
    /// How far (points) the window must move before we treat it as a window drag.
    private let moveThreshold: CGFloat = 6

    init(state: AppState,
         snapEngine: SnapEngine,
         windowManager: WindowManager,
         overlay: OverlayController) {
        self.state = state
        self.snapEngine = snapEngine
        self.windowManager = windowManager
        self.overlay = overlay
    }

    /// Install the event tap. Requires Accessibility permission; returns false if the
    /// tap couldn't be created (e.g. not yet trusted).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: dragEventCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        resetDrag()
    }

    // MARK: - Event handling (called on the main thread by the tap callback)

    func handle(type: CGEventType, location: CGPoint, flags: CGEventFlags) {
        switch type {
        case .leftMouseDown:
            mouseDown = true
            dragging = false
            engaged = false
            windowMoving = false
            draggedWindow = nil
            hoveredZoneId = nil
            lastFlags = flags
            // Remember the window under the cursor and its starting position so we
            // can detect whether this drag actually moves a window.
            candidateWindow = windowManager.window(at: location)
            startWindowOrigin = candidateWindow.flatMap { windowManager.frame(of: $0)?.origin }

        case .flagsChanged:
            lastFlags = flags
            if dragging { updateEngagement(at: location) }

        case .leftMouseDragged:
            guard mouseDown else { return }
            dragging = true
            lastFlags = flags
            updateEngagement(at: location)

        case .leftMouseUp:
            if engaged { commitSnap() }
            resetDrag()

        // The system disables a tap that's too slow or interrupted; re-enable it.
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }

        default:
            break
        }
    }

    // MARK: - Engagement

    /// Whether the current snap mode permits engaging (auto: always; modifier: keys held).
    private var modeAllowsEngage: Bool {
        switch state.settings.snapMode {
        case .auto:     return true
        case .modifier: return state.settings.modifiersSatisfied(by: lastFlags)
        }
    }

    /// Recompute whether snapping is engaged and refresh the overlay. `axPoint` is the
    /// mouse location in AX coordinates (top-left origin) as reported by the event.
    private func updateEngagement(at axPoint: CGPoint) {
        // Only engage once the candidate window has actually moved — this filters out
        // in-app drags (selecting text, dragging a slider/canvas) that never relocate
        // the window. We only poll position while the mode would engage, to keep
        // ordinary drags cheap.
        if !windowMoving, modeAllowsEngage,
           let win = candidateWindow, let start = startWindowOrigin,
           let origin = windowManager.frame(of: win)?.origin,
           hypot(origin.x - start.x, origin.y - start.y) > moveThreshold {
            windowMoving = true
        }

        guard modeAllowsEngage && windowMoving else {
            if engaged { overlay.hide() }
            engaged = false
            hoveredZoneId = nil
            return
        }

        if !engaged {
            engaged = true
            draggedWindow = candidateWindow
        }

        let cocoaPoint = Geometry.axPointToCocoa(axPoint)
        guard let screen = screen(containing: cocoaPoint) else {
            overlay.hide()
            return
        }
        currentScreen = screen

        let layout = state.layout(forScreen: screen)
        var zoneRects: [OverlayController.ZoneRect] = []
        var hovered: Int?
        for zone in layout.zones {
            // Hit-test against the gapless cell so the whole area is catchable…
            let hitRect = Geometry.cocoaRect(forNormalized: zone.rect,
                                             in: screen.visibleFrame)
            if hitRect.contains(cocoaPoint) { hovered = zone.id }
            // …but draw (and later snap to) the padded/gapped rect.
            let drawRect = snapEngine.cocoaRect(for: zone, on: screen)
            zoneRects.append(.init(id: zone.id, globalRect: drawRect))
        }
        hoveredZoneId = hovered
        let s = state.settings
        let appearance = OverlayController.Appearance(
            color: s.highlightColor.nsColor,
            opacity: CGFloat(s.overlayOpacity),
            showNumbers: s.showZoneNumbers)
        overlay.show(on: screen, zones: zoneRects, highlighted: hovered, appearance: appearance)
    }

    private func commitSnap() {
        defer { overlay.hide() }
        guard let window = draggedWindow,
              let screen = currentScreen,
              let zoneId = hoveredZoneId,
              let zone = state.layout(forScreen: screen).zones.first(where: { $0.id == zoneId }) else {
            return
        }
        snapEngine.snap(window: window, to: zone, on: screen)
    }

    private func resetDrag() {
        mouseDown = false
        dragging = false
        engaged = false
        windowMoving = false
        draggedWindow = nil
        candidateWindow = nil
        startWindowOrigin = nil
        currentScreen = nil
        hoveredZoneId = nil
    }

    private func screen(containing cocoaPoint: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(cocoaPoint) }
    }
}

/// C callback for the event tap. Runs on the main run loop (we add the source to
/// `CFRunLoopGetMain`), so it is safe to hop onto the main actor synchronously.
private func dragEventCallback(proxy: CGEventTapProxy,
                               type: CGEventType,
                               event: CGEvent,
                               userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        // Extract Sendable primitives so the non-Sendable CGEvent doesn't cross
        // into the main-actor closure.
        let location = event.location
        let flags = event.flags
        MainActor.assumeIsolated {
            monitor.handle(type: type, location: location, flags: flags)
        }
    }
    // Listen-only tap: the return value is ignored, but pass the event through.
    return Unmanaged.passUnretained(event)
}
