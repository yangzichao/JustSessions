import AppKit
import SwiftTerm

extension TerminalView {
    /// The terminal as the screen shows it. SwiftTerm leaves cells in the default background transparent, for the
    /// layer's background color to show through, and `cacheDisplay` draws only the view, so this draws it over that color.
    func snapshotOverLayerBackground() -> NSBitmapImageRep? {
        guard let drawn = bitmapImageRepForCachingDisplay(in: bounds),
            let snapshot = bitmapImageRepForCachingDisplay(in: bounds),
            let context = NSGraphicsContext(bitmapImageRep: snapshot)
        else {
            return nil
        }
        cacheDisplay(in: bounds, to: drawn)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        let snapshotRect = NSRect(origin: .zero, size: snapshot.size)
        (layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) ?? nativeBackgroundColor).setFill()
        snapshotRect.fill()
        drawn.draw(in: snapshotRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        context.flushGraphics()
        return snapshot
    }
}
