import AppKit

// Legacy .icns packaging works with the Command Line Tools and macOS 13+.
// This is a static icon, not an Icon Composer Liquid Glass asset.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
guard let source = NSImage(contentsOf: root.appendingPathComponent("Assets/Icon-source.jpg")) else {
    fatalError("Missing icon source")
}
let iconset = root.appendingPathComponent("dist/Moove.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        image.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
        let size = CGFloat(pixels)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        let inset = size * 0.0625
        let bounds = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
        NSBezierPath(roundedRect: bounds, xRadius: size * 0.19, yRadius: size * 0.19).addClip()
        source.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try image.representation(using: .png, properties: [:])!.write(to: url)
        if pixels == 1024 {
            try image.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Assets/Icon.png"))
        }
    }
}
