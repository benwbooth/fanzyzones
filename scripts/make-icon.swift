import AppKit

// Renders the FanzyZones icon (a rounded tile with a large left zone + two stacked
// right zones) into an .iconset directory for `iconutil`. Run via:
//   swift scripts/make-icon.swift <output.iconset>

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = size
    let bg = NSRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9)
    let bgPath = NSBezierPath(roundedRect: bg, xRadius: s * 0.205, yRadius: s * 0.205)
    NSGradient(colors: [
        NSColor(srgbRed: 0.24, green: 0.58, blue: 1.0, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.36, blue: 0.95, alpha: 1)
    ])?.draw(in: bgPath, angle: -90)

    let inset = bg.insetBy(dx: s * 0.15, dy: s * 0.15)
    let gap = s * 0.04
    let leftW = inset.width * 0.55 - gap / 2

    func pane(_ r: NSRect, _ alpha: CGFloat) {
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: r, xRadius: s * 0.05, yRadius: s * 0.05).fill()
    }

    pane(NSRect(x: inset.minX, y: inset.minY, width: leftW, height: inset.height), 0.95)
    let rightX = inset.minX + leftW + gap
    let rightW = inset.maxX - rightX
    let rightH = (inset.height - gap) / 2
    pane(NSRect(x: rightX, y: inset.minY + rightH + gap, width: rightW, height: rightH), 0.95)
    pane(NSRect(x: rightX, y: inset.minY, width: rightW, height: rightH), 0.78)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, px) in specs {
    let rep = drawIcon(size: px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("wrote iconset to \(outDir)")
