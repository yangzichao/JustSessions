import AppKit

enum KiroGhostIcon {
    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { bounds in
            let drawingContext = NSGraphicsContext.current?.cgContext
            drawingContext?.saveGState()
            defer { drawingContext?.restoreGState() }
            drawingContext?.translateBy(x: bounds.minX, y: bounds.minY)
            drawingContext?.scaleBy(x: bounds.width / 16, y: bounds.height / 16)

            let ghostPath = NSBezierPath()
            ghostPath.move(to: NSPoint(x: 2.5, y: 14.5))
            ghostPath.line(to: NSPoint(x: 2.5, y: 6.5))
            ghostPath.curve(
                to: NSPoint(x: 8, y: 1),
                controlPoint1: NSPoint(x: 2.5, y: 3.5),
                controlPoint2: NSPoint(x: 5, y: 1)
            )
            ghostPath.curve(
                to: NSPoint(x: 13.5, y: 6.5),
                controlPoint1: NSPoint(x: 11, y: 1),
                controlPoint2: NSPoint(x: 13.5, y: 3.5)
            )
            ghostPath.line(to: NSPoint(x: 13.5, y: 14.5))
            ghostPath.line(to: NSPoint(x: 10.75, y: 12.5))
            ghostPath.line(to: NSPoint(x: 8, y: 14.5))
            ghostPath.line(to: NSPoint(x: 5.25, y: 12.5))
            ghostPath.close()
            ghostPath.appendOval(in: NSRect(x: 5, y: 6, width: 2, height: 2.75))
            ghostPath.appendOval(in: NSRect(x: 9, y: 6, width: 2, height: 2.75))
            ghostPath.windingRule = .evenOdd
            NSColor.black.setFill()
            ghostPath.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
