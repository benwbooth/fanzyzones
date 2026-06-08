import CoreGraphics

/// The default layouts offered out of the box. All zones are normalized
/// (top-left origin, 0…1). Helpers build columns/grids so the math stays in one place.
enum BuiltInLayouts {

    static let all: [Layout] = [
        twoPanes,
        twoPanesWide,
        threePanes,
        threePanesUltrawide,
        quarters,
        priorityLeft,
        gridThreeByThree
    ]

    // MARK: - Definitions

    /// 50 / 50 left-right.
    static let twoPanes = columns(
        id: "builtin.two-panes", name: "Two Panes",
        widths: [0.5, 0.5], names: ["Left", "Right"])

    /// 70 / 30 — a wide primary pane plus a sidebar.
    static let twoPanesWide = columns(
        id: "builtin.two-panes-wide", name: "Two Panes (Wide + Side)",
        widths: [0.7, 0.3], names: ["Main", "Side"])

    /// Even thirds.
    static let threePanes = columns(
        id: "builtin.three-panes", name: "Three Panes",
        widths: [1.0/3, 1.0/3, 1.0/3], names: ["Left", "Center", "Right"])

    /// Ultrawide-friendly: narrow sides, dominant center.
    static let threePanesUltrawide = columns(
        id: "builtin.three-panes-ultrawide", name: "Three Panes (Ultrawide)",
        widths: [0.25, 0.5, 0.25], names: ["Left", "Center", "Right"])

    /// 2×2 grid.
    static let quarters = grid(
        id: "builtin.quarters", name: "Quarters",
        rows: 2, cols: 2,
        names: ["Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"])

    /// 3×3 grid.
    static let gridThreeByThree = grid(
        id: "builtin.grid-3x3", name: "Grid 3×3",
        rows: 3, cols: 3, names: nil)

    /// Priority/focus: big left pane (60%) full-height, right column split top/bottom.
    static let priorityLeft = Layout(
        id: "builtin.priority-left", name: "Priority (Left Focus)",
        zones: [
            Zone(id: 0, name: "Focus",
                 rect: CGRect(x: 0, y: 0, width: 0.6, height: 1)),
            Zone(id: 1, name: "Top-Right",
                 rect: CGRect(x: 0.6, y: 0, width: 0.4, height: 0.5)),
            Zone(id: 2, name: "Bottom-Right",
                 rect: CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5))
        ],
        isBuiltIn: true)

    // MARK: - Builders

    /// Build a left-to-right column layout from fractional widths summing to 1.
    static func columns(id: String, name: String,
                        widths: [CGFloat], names: [String]) -> Layout {
        var zones: [Zone] = []
        var x: CGFloat = 0
        for (i, w) in widths.enumerated() {
            zones.append(Zone(id: i, name: names[i],
                              rect: CGRect(x: x, y: 0, width: w, height: 1)))
            x += w
        }
        return Layout(id: id, name: name, zones: zones, isBuiltIn: true)
    }

    /// Build a uniform grid. If `names` is nil, zones are numbered.
    static func grid(id: String, name: String,
                     rows: Int, cols: Int, names: [String]?) -> Layout {
        var zones: [Zone] = []
        let w = 1.0 / CGFloat(cols)
        let h = 1.0 / CGFloat(rows)
        var index = 0
        for r in 0..<rows {
            for c in 0..<cols {
                let zoneName = names?[index] ?? "Zone \(index + 1)"
                zones.append(Zone(id: index, name: zoneName,
                                  rect: CGRect(x: CGFloat(c) * w,
                                               y: CGFloat(r) * h,
                                               width: w, height: h)))
                index += 1
            }
        }
        return Layout(id: id, name: name, zones: zones, isBuiltIn: true)
    }
}
