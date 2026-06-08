import AppKit
import CoreGraphics

/// Identifies displays by a stable UUID (survives reconnect / rearrangement), so
/// per-display layout assignments stick to the right monitor.
enum DisplayManager {
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }

    /// Stable UUID string for a screen, or nil if it can't be determined.
    static func uuid(of screen: NSScreen) -> String? {
        let id = displayID(of: screen)
        guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, cf) as String?
    }

    /// All connected displays with their UUID, friendly name, and screen.
    static func displays() -> [(uuid: String, name: String, screen: NSScreen)] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = uuid(of: screen) else { return nil }
            return (uuid, screen.localizedName, screen)
        }
    }

    /// UUID of the main display (the one with the menu bar / key focus).
    static func mainUUID() -> String? {
        guard let main = NSScreen.main else { return uuid(of: NSScreen.screens.first ?? NSScreen()) }
        return uuid(of: main)
    }
}
