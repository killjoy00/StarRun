// Generate a non-transparent 1024px App Store icon matching assets/icon.svg.
// Uses only macOS AppKit so cloud builds need no image dependencies.
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift tools/generate-ios-icon.swift assets/ios-icon.png\n", stderr)
    exit(2)
}
let n = 1024
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Cannot allocate icon")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.translateBy(x: 0, y: CGFloat(n))
context.scaleBy(x: 4, y: -4)
func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
context.setFillColor(color(0x070c19))
context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
context.beginPath()
context.move(to: CGPoint(x: 128, y: 37))
context.addLine(to: CGPoint(x: 199, y: 200))
context.addLine(to: CGPoint(x: 128, y: 168))
context.addLine(to: CGPoint(x: 57, y: 200))
context.closePath()
context.setFillColor(color(0x123b49))
context.setStrokeColor(color(0x60f4e1))
context.setLineWidth(9)
context.setLineJoin(.round)
context.drawPath(using: .fillStroke)
context.beginPath()
context.move(to: CGPoint(x: 128, y: 78))
context.addLine(to: CGPoint(x: 128, y: 164))
context.move(to: CGPoint(x: 105, y: 189))
context.addLine(to: CGPoint(x: 128, y: 222))
context.addLine(to: CGPoint(x: 151, y: 189))
context.setStrokeColor(color(0xfcba69))
context.setLineWidth(8)
context.setLineCap(.round)
context.setLineJoin(.round)
context.strokePath()
NSGraphicsContext.restoreGraphicsState()
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode PNG")
}
try png.write(to: url)
print("Wrote \(url.path) (\(n)x\(n), opaque)")
