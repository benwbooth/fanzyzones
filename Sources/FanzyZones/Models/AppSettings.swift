import AppKit

/// When zone snapping engages during a drag.
enum SnapMode: String, Codable {
    /// Engage whenever any window is dragged.
    case auto
    /// Engage only while the configured modifier(s) are held (default: Shift).
    case modifier
}

/// A modifier key, mapped to both Cocoa and CoreGraphics flag sets.
enum ModifierKey: String, Codable, CaseIterable {
    case shift, control, option, command

    var cgFlag: CGEventFlags {
        switch self {
        case .shift:   return .maskShift
        case .control: return .maskControl
        case .option:  return .maskAlternate
        case .command: return .maskCommand
        }
    }

    var displayName: String {
        switch self {
        case .shift:   return "Shift"
        case .control: return "Control"
        case .option:  return "Option"
        case .command: return "Command"
        }
    }
}

/// User-tunable settings, persisted as JSON.
struct AppSettings: Codable, Equatable {
    var snapMode: SnapMode = .modifier
    var modifiers: Set<ModifierKey> = [.shift]
    /// The layout used for drag-to-snap and the default for menu snapping.
    var activeLayoutId: String = BuiltInLayouts.twoPanes.id
    /// Empty space between adjacent zones, in points. Default 0 = edge-to-edge.
    var gap: CGFloat = 0
    /// Empty space around the whole work area, in points.
    var padding: CGFloat = 0
    /// Global keyboard shortcuts for snapping (⌃⌥arrows, ⌃⌥1…9).
    var keyboardShortcutsEnabled: Bool = true
    /// Color of the drag-time zone overlay.
    var highlightColor: RGBColor = .defaultHighlight
    /// Fill opacity of the highlighted zone (others derive from this).
    var overlayOpacity: Double = 0.35
    /// Show zone numbers in the overlay while dragging.
    var showZoneNumbers: Bool = true

    /// True if `flags` satisfies all configured modifiers (ignoring extra keys).
    func modifiersSatisfied(by flags: CGEventFlags) -> Bool {
        guard !modifiers.isEmpty else { return false }
        return modifiers.allSatisfy { flags.contains($0.cgFlag) }
    }

    init() {}

    // Resilient decoding: any key missing from an older settings.json falls back to
    // its default instead of throwing (which would reset all settings).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        snapMode = try c.decodeIfPresent(SnapMode.self, forKey: .snapMode) ?? d.snapMode
        modifiers = try c.decodeIfPresent(Set<ModifierKey>.self, forKey: .modifiers) ?? d.modifiers
        activeLayoutId = try c.decodeIfPresent(String.self, forKey: .activeLayoutId) ?? d.activeLayoutId
        gap = try c.decodeIfPresent(CGFloat.self, forKey: .gap) ?? d.gap
        padding = try c.decodeIfPresent(CGFloat.self, forKey: .padding) ?? d.padding
        keyboardShortcutsEnabled = try c.decodeIfPresent(Bool.self, forKey: .keyboardShortcutsEnabled) ?? d.keyboardShortcutsEnabled
        highlightColor = try c.decodeIfPresent(RGBColor.self, forKey: .highlightColor) ?? d.highlightColor
        overlayOpacity = try c.decodeIfPresent(Double.self, forKey: .overlayOpacity) ?? d.overlayOpacity
        showZoneNumbers = try c.decodeIfPresent(Bool.self, forKey: .showZoneNumbers) ?? d.showZoneNumbers
    }
}
