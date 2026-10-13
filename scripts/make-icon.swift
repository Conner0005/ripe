// Draws the app icon (tomato-red tile, white progress ring, green leaf) and writes Resources/AppIcon.icns.
// Run: swift scripts/make-icon.swift
import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: size / 1024, y: size / 1024) // draw on a 1024 grid

    // Tile: Apple's macOS grid is an 824pt rounded square centred in 1024, with a soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [NSColor(red: 1.00, green: 0.45, blue: 0.36, alpha: 1).cgColor,
                                       NSColor(red: 0.85, green: 0.22, blue: 0.20, alpha: 1).cgColor] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Ring: faint full track, then a bright arc for the time left (clockwise from 12 o'clock).
    let centre = CGPoint(x: 512, y: 490)
    let radius: CGFloat = 250
    ctx.setLineWidth(64)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    ctx.addArc(center: centre, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.addArc(center: centre, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.5, clockwise: true)
    ctx.strokePath()

    // Leaf: two green petals and a stem at the top of the ring, like a tomato's calyx.
    let green = NSColor(red: 0.30, green: 0.72, blue: 0.40, alpha: 1).cgColor
    ctx.setFillColor(green)
    for angle in [CGFloat.pi * 0.18, -CGFloat.pi * 0.18] {
        ctx.saveGState()
        ctx.translateBy(x: 512, y: 760)
        ctx.rotate(by: angle)
        ctx.fillEllipse(in: CGRect(x: -110, y: -34, width: 220, height: 68).offsetBy(dx: angle > 0 ? -95 : 95, dy: 0))
        ctx.restoreGState()
    }
    ctx.fillEllipse(in: CGRect(x: 457, y: 692, width: 110, height: 110))
    ctx.setStrokeColor(green)
    ctx.setLineWidth(34)
    ctx.move(to: CGPoint(x: 512, y: 760))
    ctx.addCurve(to: CGPoint(x: 545, y: 850), control1: CGPoint(x: 512, y: 810), control2: CGPoint(x: 525, y: 835))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = drawIcon(size: CGFloat(points * scale)).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
