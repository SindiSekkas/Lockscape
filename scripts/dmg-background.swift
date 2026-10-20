// Renders the disk image background (title, hint and the drag arrow) into dmg/background.png
// and dmg/background@2x.png for a 660x400 Finder window. Usage: swift scripts/dmg-background.swift
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("dmg")
let size = NSSize(width: 660, height: 400)

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                               pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    func draw(_ text: String, font: NSFont, color: NSColor, centerY: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let width = (text as NSString).size(withAttributes: attributes).width
        (text as NSString).draw(at: NSPoint(x: (size.width - width) / 2, y: centerY - font.pointSize / 2),
                                withAttributes: attributes)
    }
    draw("Install Lockscape", font: .boldSystemFont(ofSize: 28), color: NSColor(white: 0.15, alpha: 1), centerY: 335)
    draw("Drag the app onto the Applications folder", font: .systemFont(ofSize: 15),
         color: NSColor(white: 0.45, alpha: 1), centerY: 300)

    // Arrow between the icon slots (icons sit at x = 160 and x = 500, y = 185 from the top).
    let y: CGFloat = size.height - 185
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 265, y: y))
    arrow.line(to: NSPoint(x: 370, y: y))
    arrow.lineWidth = 8
    arrow.lineCapStyle = .round
    NSColor(red: 0.16, green: 0.22, blue: 0.70, alpha: 1).set()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 365, y: y - 22))
    head.line(to: NSPoint(x: 405, y: y))
    head.line(to: NSPoint(x: 365, y: y + 22))
    head.close()
    head.fill()

    return rep.representation(using: .png, properties: [:])!
}

try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try! render(scale: 1).write(to: output.appendingPathComponent("background.png"))
try! render(scale: 2).write(to: output.appendingPathComponent("background@2x.png"))
print("Background written to \(output.path)")
