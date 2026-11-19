import AppKit

enum CodexPromptHexagonIcon {
    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { bounds in
            let drawingContext = NSGraphicsContext.current?.cgContext
            drawingContext?.saveGState()
            defer { drawingContext?.restoreGState() }
            drawingContext?.translateBy(x: bounds.minX, y: bounds.minY)
            drawingContext?.scaleBy(x: bounds.width / 16, y: bounds.height / 16)

            NSColor.black.setFill()
            roundedHexagonPath().fill()

            let promptPath = NSBezierPath()
            promptPath.move(to: NSPoint(x: 4.6, y: 5.6))
            promptPath.line(to: NSPoint(x: 7.2, y: 8))
            promptPath.line(to: NSPoint(x: 4.6, y: 10.4))
            promptPath.move(to: NSPoint(x: 8.6, y: 10.4))
            promptPath.line(to: NSPoint(x: 11.4, y: 10.4))
            promptPath.lineWidth = 1.7
            promptPath.lineCapStyle = .round
            promptPath.lineJoinStyle = .round
            drawingContext?.setBlendMode(.clear)
            promptPath.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func roundedHexagonPath() -> NSBezierPath {
        let cornerDistanceFromCenter: CGFloat = 7.6
        let corners = (0..<6).map { cornerIndex in
            let angle = CGFloat(cornerIndex) * .pi / 3 - .pi / 2
            return NSPoint(x: 8 + cornerDistanceFromCenter * cos(angle), y: 8 + cornerDistanceFromCenter * sin(angle))
        }
        let hexagonPath = NSBezierPath()
        hexagonPath.move(to: NSPoint(x: (corners[5].x + corners[0].x) / 2, y: (corners[5].y + corners[0].y) / 2))
        for cornerIndex in corners.indices {
            hexagonPath.appendArc(from: corners[cornerIndex], to: corners[(cornerIndex + 1) % corners.count], radius: 1.6)
        }
        hexagonPath.close()
        return hexagonPath
    }
}
