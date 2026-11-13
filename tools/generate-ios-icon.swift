// Generate an opaque 1024px PNG mirroring assets/icon.svg.
// CoreGraphics works without AppKit or a window server on macOS CI.
import Foundation
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift tools/generate-ios-icon.swift assets/ios-icon.png\n", stderr)
    exit(2)
}
let n = 1024
guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Cannot allocate CoreGraphics image context")
}
ctx.translateBy(x: 0, y: CGFloat(n))
ctx.scaleBy(x: 4, y: -4)
func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
ctx.setFillColor(color(0x070c19))
ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
ctx.beginPath()
ctx.move(to: CGPoint(x: 128, y: 37))
ctx.addLine(to: CGPoint(x: 199, y: 200))
ctx.addLine(to: CGPoint(x: 128, y: 168))
ctx.addLine(to: CGPoint(x: 57, y: 200))
ctx.closePath()
ctx.setFillColor(color(0x123b49))
ctx.setStrokeColor(color(0x60f4e1))
ctx.setLineWidth(9)
ctx.setLineJoin(.round)
ctx.drawPath(using: .fillStroke)
ctx.beginPath()
ctx.move(to: CGPoint(x: 128, y: 78))
ctx.addLine(to: CGPoint(x: 128, y: 164))
ctx.move(to: CGPoint(x: 105, y: 189))
ctx.addLine(to: CGPoint(x: 128, y: 222))
ctx.addLine(to: CGPoint(x: 151, y: 189))
ctx.setStrokeColor(color(0xfcba69))
ctx.setLineWidth(8)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.strokePath()
guard let image = ctx.makeImage() else { fatalError("Cannot render icon") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Cannot create PNG destination")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write PNG") }
print("Wrote \(url.path) (\(n)x\(n), opaque)")
