// Renders Tether's app icon and DMG background.
// Usage: swift scripts/render-art.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func png(_ size: CGSize, scale: CGFloat = 1, _ name: String, _ draw: (CGContext, CGSize) -> Void) {
    let px = CGSize(width: size.width * scale, height: size.height * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: scale, y: scale)
    draw(ctx, size)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// Padlock + signal arcs, centred at `c`, sized by `u` (unit ≈ lock body width / 4).
func drawGlyph(_ ctx: CGContext, center c: CGPoint, unit u: CGFloat, ink: CGColor) {
    // Lock body
    let body = CGRect(x: c.x - 2.1 * u, y: c.y - 2.6 * u, width: 4.2 * u, height: 3.3 * u)
    ctx.setFillColor(ink)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 0.7 * u, cornerHeight: 0.7 * u, transform: nil))
    ctx.fillPath()
    // Shackle
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(0.62 * u)
    ctx.setLineCap(.round)
    let sx = c.x, sy = body.maxY
    ctx.move(to: CGPoint(x: sx - 1.3 * u, y: sy))
    ctx.addLine(to: CGPoint(x: sx - 1.3 * u, y: sy + 0.7 * u))
    ctx.addArc(center: CGPoint(x: sx, y: sy + 0.7 * u), radius: 1.3 * u, startAngle: .pi, endAngle: 0, clockwise: true)
    ctx.addLine(to: CGPoint(x: sx + 1.3 * u, y: sy))
    ctx.strokePath()
    // Keyhole (cut out)
    ctx.setBlendMode(.clear)
    let kh = CGPoint(x: c.x, y: body.midY + 0.2 * u)
    ctx.fillEllipse(in: CGRect(x: kh.x - 0.38 * u, y: kh.y - 0.38 * u, width: 0.76 * u, height: 0.76 * u))
    ctx.fill(CGRect(x: kh.x - 0.16 * u, y: kh.y - 1.0 * u, width: 0.32 * u, height: 0.9 * u))
    ctx.setBlendMode(.normal)
    // Signal arcs: the invisible tether
    let origin = CGPoint(x: c.x, y: sy + 0.7 * u)
    for (i, alpha) in [0.95, 0.7, 0.45].enumerated() {
        let r = (2.45 + CGFloat(i) * 0.95) * u
        ctx.setStrokeColor(ink.copy(alpha: alpha)!)
        ctx.setLineWidth(0.42 * u)
        ctx.addArc(center: origin, radius: r, startAngle: .pi * 0.28, endAngle: .pi * 0.72, clockwise: false)
        ctx.strokePath()
    }
}

// MARK: App icon (1024, macOS grid: 824pt squircle with shadow)
png(CGSize(width: 1024, height: 1024), "icon_1024.png") { ctx, size in
    let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(shape); ctx.setFillColor(color(0x1B2A6B)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [color(0x5B6CFF), color(0x2F3FD8), color(0x0E8FB8)] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
    // soft top highlight
    let hi = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hi, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // Glyph on its own layer so the keyhole only clears the glyph.
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x0A1240, 0.35))
    drawGlyph(ctx, center: CGPoint(x: 512, y: 470), unit: 72, ink: color(0xFFFFFF))
    ctx.endTransparencyLayer()
}

// MARK: DMG background (660×400 @1x and @2x)
for scale: CGFloat in [1, 2] {
    png(CGSize(width: 660, height: 400), scale: scale, scale == 1 ? "dmg-background.png" : "dmg-background@2x.png") { ctx, size in
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0xF7F8FF), color(0xE6EBFF)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [])

        // Arrow between the app (x=170) and Applications (x=490) icons, icon centre y = 400-200 = 200
        ctx.setStrokeColor(color(0x5B6CFF, 0.55))
        ctx.setLineWidth(5)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [2, 14])
        ctx.move(to: CGPoint(x: 265, y: 200)); ctx.addLine(to: CGPoint(x: 385, y: 200)); ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: 375, y: 214)); ctx.addLine(to: CGPoint(x: 395, y: 200)); ctx.addLine(to: CGPoint(x: 375, y: 186))
        ctx.strokePath()

        func text(_ s: String, y: CGFloat, size fs: CGFloat, weight: NSFont.Weight, color c: NSColor) {
            let style = NSMutableParagraphStyle(); style.alignment = .center
            let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fs, weight: weight), .foregroundColor: c, .paragraphStyle: style]
            NSAttributedString(string: s, attributes: attr).draw(in: CGRect(x: 0, y: y, width: size.width, height: fs * 1.5))
        }
        text("Tether", y: 330, size: 26, weight: .bold, color: NSColor(red: 0.11, green: 0.16, blue: 0.42, alpha: 1))
        text("Kéo Tether vào thư mục Applications để cài đặt", y: 300, size: 13, weight: .regular, color: NSColor(white: 0.35, alpha: 1))
        text("Mang iPhone hoặc Apple Watch đi xa, Mac tự khoá.", y: 52, size: 12, weight: .regular, color: NSColor(white: 0.45, alpha: 1))
    }
}
print("ok")
