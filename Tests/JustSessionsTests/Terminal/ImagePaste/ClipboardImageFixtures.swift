import AppKit

@testable import JustSessions

/// A small PNG whose pixels aren't all the same.
func makePNGData(width: Int = 6, height: Int = 4) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    for x in 0..<width {
        for y in 0..<height {
            let color = NSColor(red: CGFloat(x) / CGFloat(width), green: CGFloat(y) / CGFloat(height), blue: 0.5, alpha: 1)
            bitmap.setColor(color, atX: x, y: y)
        }
    }
    return bitmap.representation(using: .png, properties: [:])!
}

extension NSPasteboard {
    /// A pasteboard of its own holding one item with `representations`, as a screenshot copied to the clipboard does.
    static func holding(_ representations: [NSPasteboard.PasteboardType: Data]) -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        let item = NSPasteboardItem()
        for (type, data) in representations { item.setData(data, forType: type) }
        pasteboard.writeObjects([item])
        return pasteboard
    }
}
