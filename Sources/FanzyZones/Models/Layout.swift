import CoreGraphics

/// A named arrangement of zones. Built-in layouts are generated in code and are
/// read-only; user layouts come from the editor and are saved to disk.
struct Layout: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var zones: [Zone]
    var isBuiltIn: Bool

    init(id: String, name: String, zones: [Zone], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.zones = zones
        self.isBuiltIn = isBuiltIn
    }
}
