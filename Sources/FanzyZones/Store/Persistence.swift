import Foundation

/// JSON persistence under `~/Library/Application Support/FanzyZones/`.
/// Built-in layouts are not stored here — only user settings and custom layouts.
enum Persistence {
    private static let folderName = "FanzyZones"
    private static let settingsFile = "settings.json"
    private static let layoutsFile = "layouts.json"
    private static let assignmentsFile = "assignments.json"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
    }

    // MARK: - Settings

    static func loadSettings() -> AppSettings {
        let url = directory.appendingPathComponent(settingsFile)
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    static func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? ensureDirectory()
        try? data.write(to: directory.appendingPathComponent(settingsFile))
    }

    // MARK: - Custom layouts

    static func loadCustomLayouts() -> [Layout] {
        let url = directory.appendingPathComponent(layoutsFile)
        guard let data = try? Data(contentsOf: url),
              let layouts = try? JSONDecoder().decode([Layout].self, from: data) else {
            return []
        }
        return layouts
    }

    static func saveCustomLayouts(_ layouts: [Layout]) {
        guard let data = try? encoder.encode(layouts) else { return }
        try? ensureDirectory()
        try? data.write(to: directory.appendingPathComponent(layoutsFile))
    }

    // MARK: - Per-display assignments (displayUUID -> layoutId)

    static func loadAssignments() -> [String: String] {
        let url = directory.appendingPathComponent(assignmentsFile)
        guard let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    static func saveAssignments(_ assignments: [String: String]) {
        guard let data = try? encoder.encode(assignments) else { return }
        try? ensureDirectory()
        try? data.write(to: directory.appendingPathComponent(assignmentsFile))
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
