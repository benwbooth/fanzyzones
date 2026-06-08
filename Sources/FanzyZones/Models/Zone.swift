import CoreGraphics

/// One pane within a layout, expressed in normalized coordinates (0…1) with a
/// top-left origin so it scales to any display. Converted to pixels per-display by
/// `Geometry`.
struct Zone: Codable, Identifiable, Equatable {
    /// Index within its layout (also the order shown in menus / overlay labels).
    var id: Int
    var name: String
    var rect: CGRect

    init(id: Int, name: String, rect: CGRect) {
        self.id = id
        self.name = name
        self.rect = rect
    }
}
