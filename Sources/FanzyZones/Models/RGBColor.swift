import AppKit
import SwiftUI

/// A simple sRGB color we can persist in JSON and convert to/from `NSColor`/`Color`.
struct RGBColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let defaultHighlight = RGBColor(red: 0.0, green: 0.48, blue: 1.0)

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
        self.red = Double(ns.redComponent)
        self.green = Double(ns.greenComponent)
        self.blue = Double(ns.blueComponent)
    }
}
