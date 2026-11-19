import AppKit

enum OpenCodeBlockRingIcon {
    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { bounds in
            let drawingContext = NSGraphicsContext.current?.cgContext
            drawingContext?.saveGState()
            defer { drawingContext?.restoreGState() }
            drawingContext?.translateBy(x: bounds.minX, y: bounds.minY)
            drawingContext?.scaleBy(x: bounds.width / 16, y: bounds.height / 16)

            let ringPath = NSBezierPath(roundedRect: NSRect(x: 2.6, y: 1.5, width: 10.8, height: 13), xRadius: 1.6, yRadius: 1.6)
            ringPath.append(NSBezierPath(roundedRect: NSRect(x: 5.6, y: 4.4, width: 4.8, height: 7.2), xRadius: 0.6, yRadius: 0.6))
            ringPath.windingRule = .evenOdd
            NSColor.black.setFill()
            ringPath.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
