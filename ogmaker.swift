import AppKit

// Renders docs/og.png (1200×630 social card): graphite ground, the app icon,
// wordmark + one-liner. Run:  swift ogmaker.swift docs/og.png
// Reuses the same icon geometry as iconmaker.swift.

func drawIcon(in rect: NSRect) {
    let S = rect.width
    let margin = S * 0.098
    let side = S - margin * 2
    let frame = NSRect(x: rect.minX + margin, y: rect.minY + margin, width: side, height: side)
    let squircle = NSBezierPath(roundedRect: frame, xRadius: side * 0.2237, yRadius: side * 0.2237)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = side * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.025)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.set()
    NSColor(calibratedRed: 0.137, green: 0.137, blue: 0.153, alpha: 1).setFill()
    squircle.fill()
    let none = NSShadow(); none.shadowColor = nil; none.set()

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.220, green: 0.220, blue: 0.235, alpha: 1),
        NSColor(calibratedRed: 0.121, green: 0.121, blue: 0.137, alpha: 1)])!
        .draw(in: frame, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let cx = rect.midX, cy = rect.midY
    let ow = side * 0.40, oh = side * 0.60
    let oval = NSBezierPath(ovalIn: NSRect(x: cx - ow/2, y: cy - oh/2, width: ow, height: oh))
    oval.lineWidth = side * 0.024
    oval.lineCapStyle = .round
    let dash: [CGFloat] = [side * 0.050, side * 0.060]
    dash.withUnsafeBufferPointer { oval.setLineDash($0.baseAddress, count: $0.count, phase: 0) }
    NSColor(calibratedRed: 0.706, green: 0.706, blue: 0.725, alpha: 1).setStroke()
    oval.stroke()

    let capW = side * 0.058, capH = side * 0.155
    let capRect = NSRect(x: cx - capW/2, y: cy + side * 0.115 - capH/2, width: capW, height: capH)
    NSColor(calibratedRed: 0.776, green: 0.776, blue: 0.796, alpha: 1).setFill()
    NSBezierPath(roundedRect: capRect, xRadius: capW/2, yRadius: capW/2).fill()
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "og.png"
let W: CGFloat = 1200, H: CGFloat = 630

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.086, alpha: 1).setFill()   // #131316
NSRect(x: 0, y: 0, width: W, height: H).fill()

drawIcon(in: NSRect(x: 96, y: (H - 360)/2, width: 360, height: 360))

let title = NSAttributedString(string: "Pointer", attributes: [
    .font: NSFont.systemFont(ofSize: 104, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.91, green: 0.91, blue: 0.92, alpha: 1),
    .kern: -2.0,
])
title.draw(at: NSPoint(x: 512, y: 316))

let sub = NSAttributedString(string: "Smooth scrolling & mouse button remapping\nfor your Mac. Tiny, open source, no telemetry.", attributes: [
    .font: NSFont.systemFont(ofSize: 34, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.60, green: 0.60, blue: 0.63, alpha: 1),
])
sub.draw(at: NSPoint(x: 516, y: 210))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
