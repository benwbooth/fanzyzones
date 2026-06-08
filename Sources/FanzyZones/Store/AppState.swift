import AppKit

/// Single source of truth for settings + layouts, shared by the menu and the drag
/// engine. Mutations persist immediately and notify observers so the menu rebuilds.
@MainActor
final class AppState {
    private(set) var settings: AppSettings
    private(set) var customLayouts: [Layout]
    /// displayUUID -> layoutId. Displays without an entry fall back to the default.
    private(set) var assignments: [String: String]

    /// Called whenever settings or layouts change (menu rebuilds on this).
    var onChange: (() -> Void)?

    init() {
        settings = Persistence.loadSettings()
        customLayouts = Persistence.loadCustomLayouts()
        assignments = Persistence.loadAssignments()
    }

    /// Built-in layouts first, then user layouts.
    var allLayouts: [Layout] { BuiltInLayouts.all + customLayouts }

    func layout(withId id: String) -> Layout? {
        allLayouts.first { $0.id == id }
    }

    /// The default layout (fallback for displays without a specific assignment).
    var activeLayout: Layout {
        layout(withId: settings.activeLayoutId) ?? BuiltInLayouts.all[0]
    }

    // MARK: - Per-display layouts

    /// The layout id active on a given display: its assignment, else the default.
    func layoutId(forDisplayUUID uuid: String?) -> String {
        if let uuid, let id = assignments[uuid], layout(withId: id) != nil { return id }
        return settings.activeLayoutId
    }

    /// The layout active on a display (resolved from its assignment or the default).
    func layout(forScreen screen: NSScreen) -> Layout {
        let uuid = DisplayManager.uuid(of: screen)
        return layout(withId: layoutId(forDisplayUUID: uuid)) ?? activeLayout
    }

    /// Assign a layout to a specific display. Also updates the global default when the
    /// target is the main display, so keyboard snapping and new displays stay sensible.
    func setLayout(_ layoutId: String, forDisplayUUID uuid: String) {
        assignments[uuid] = layoutId
        Persistence.saveAssignments(assignments)
        if uuid == DisplayManager.mainUUID() {
            settings.activeLayoutId = layoutId
            Persistence.saveSettings(settings)
        }
        onChange?()
    }

    // MARK: - Mutations

    func setActiveLayout(_ id: String) {
        settings.activeLayoutId = id
        persistSettingsAndNotify()
    }

    func setSnapMode(_ mode: SnapMode) {
        settings.snapMode = mode
        persistSettingsAndNotify()
    }

    func setModifiers(_ modifiers: Set<ModifierKey>) {
        settings.modifiers = modifiers
        persistSettingsAndNotify()
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        persistSettingsAndNotify()
    }

    func replaceSettings(_ newSettings: AppSettings) {
        settings = newSettings
        persistSettingsAndNotify()
    }

    /// Add or replace a custom layout by id.
    func upsertCustomLayout(_ layout: Layout) {
        if let idx = customLayouts.firstIndex(where: { $0.id == layout.id }) {
            customLayouts[idx] = layout
        } else {
            customLayouts.append(layout)
        }
        Persistence.saveCustomLayouts(customLayouts)
        onChange?()
    }

    func deleteCustomLayout(id: String) {
        customLayouts.removeAll { $0.id == id }
        if settings.activeLayoutId == id {
            settings.activeLayoutId = BuiltInLayouts.all[0].id
            Persistence.saveSettings(settings)
        }
        // Drop any per-display assignments pointing at the deleted layout.
        let staleDisplays = assignments.filter { $0.value == id }.map(\.key)
        if !staleDisplays.isEmpty {
            staleDisplays.forEach { assignments[$0] = nil }
            Persistence.saveAssignments(assignments)
        }
        Persistence.saveCustomLayouts(customLayouts)
        onChange?()
    }

    private func persistSettingsAndNotify() {
        Persistence.saveSettings(settings)
        onChange?()
    }
}
