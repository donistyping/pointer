import AppKit

// Draws the Pointer app icon: a graphite squircle (with macOS-style margin +
// soft shadow), a dashed-oval mouse body, and a solid scroll-wheel capsule.
// Renders every size the .iconset needs. Run:  swift iconmaker.swift <out.iconset>

func makeIcon(_ size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let S = size
    let margin = S * 0.098
    let side = S - margin * 2
    let frame = NSRect(x: margin, y: margin, width: side, height: side)
    let radius = side * 0.2237
    let squircle = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)

    // soft drop shadow + base silhouette
    let shadow = NSShadow()
    shadow.shadowBlurRadius = side * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.022)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.set()
    NSColor(calibratedRed: 0.137, green: 0.137, blue: 0.153, alpha: 1).setFill()
    squircle.fill()

    // clear shadow before the rest
    let none = NSShadow(); none.shadowColor = nil; none.set()

    // graphite gradient (light top → dark bottom), clipped to the squircle
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.220, green: 0.220, blue: 0.235, alpha: 1),
        NSColor(calibratedRed: 0.121, green: 0.121, blue: 0.137, alpha: 1)])!
    grad.draw(in: frame, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let cx = S / 2
    let cy = S / 2

    // dashed-oval mouse body
    let ow = side * 0.40
    let oh = side * 0.60
    let oval = NSBezierPath(ovalIn: NSRect(x: cx - ow/2, y: cy - oh/2, width: ow, height: oh))
    oval.lineWidth = side * 0.024
    oval.lineCapStyle = .round
    let dash: [CGFloat] = [side * 0.050, side * 0.060]
    dash.withUnsafeBufferPointer { oval.setLineDash($0.baseAddress, count: $0.count, phase: 0) }
    NSColor(calibratedRed: 0.706, green: 0.706, blue: 0.725, alpha: 1).setStroke()
    oval.stroke()

    // scroll-wheel capsule, upper-center
    let capW = side * 0.058
    let capH = side * 0.155
    let capRect = NSRect(x: cx - capW/2, y: cy + side * 0.115 - capH/2, width: capW, height: capH)
    let cap = NSBezierPath(roundedRect: capRect, xRadius: capW/2, yRadius: capW/2)
    NSColor(calibratedRed: 0.776, green: 0.776, blue: 0.796, alpha: 1).setFill()
    cap.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Pointer.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, sz) in specs {
    let rep = makeIcon(sz)
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    }
}
print("wrote \(specs.count) icons to \(outDir)")
