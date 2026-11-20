import AppKit
import Testing

@MainActor
enum TerminalClick {
    static func click(_ view: NSView, column: Int, modifierFlags: NSEvent.ModifierFlags) throws {
        try click(view, at: firstRowLocation(in: view, column: column), modifierFlags: modifierFlags)
    }

    static func click(
        _ view: NSView, column: Int, row: Int, in grid: TerminalTestGrid, modifierFlags: NSEvent.ModifierFlags
    ) throws {
        try click(view, at: grid.location(ofColumn: column, row: row, in: view), modifierFlags: modifierFlags)
    }

    static func rightClick(_ view: NSView, column: Int, row: Int, in grid: TerminalTestGrid) throws -> NSEvent {
        let location = grid.location(ofColumn: column, row: row, in: view)
        view.mouseMoved(with: try event(.mouseMoved, at: location, in: view, modifierFlags: []))
        return try event(.rightMouseDown, at: location, in: view, modifierFlags: [])
    }

    private static func click(_ view: NSView, at location: CGPoint, modifierFlags: NSEvent.ModifierFlags) throws {
        view.mouseMoved(with: try event(.mouseMoved, at: location, in: view, modifierFlags: modifierFlags))
        view.mouseDown(with: try event(.leftMouseDown, at: location, in: view, modifierFlags: modifierFlags))
        view.mouseUp(with: try event(.leftMouseUp, at: location, in: view, modifierFlags: modifierFlags))
    }

    static func rightClick(_ view: NSView, column: Int) throws -> NSEvent {
        let location = firstRowLocation(in: view, column: column)
        view.mouseMoved(with: try event(.mouseMoved, at: location, in: view, modifierFlags: []))
        return try event(.rightMouseDown, at: location, in: view, modifierFlags: [])
    }

    static func rightClick(_ view: NSView, at location: CGPoint) throws -> NSEvent {
        try event(.rightMouseDown, at: location, in: view, modifierFlags: [])
    }

    private static let approximateDefaultFontCellWidthInBothEngines: CGFloat = 7.5

    private static func firstRowLocation(in view: NSView, column: Int) -> CGPoint {
        CGPoint(x: (CGFloat(column) + 0.5) * approximateDefaultFontCellWidthInBothEngines, y: view.bounds.height - 4)
    }

    private static func event(
        _ type: NSEvent.EventType, at location: CGPoint, in view: NSView, modifierFlags: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        let window = try #require(view.window)
        return try #require(
            NSEvent.mouseEvent(
                with: type, location: view.convert(location, to: nil), modifierFlags: modifierFlags, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                clickCount: type == .mouseMoved ? 0 : 1, pressure: type == .leftMouseUp ? 0 : 1
            ))
    }
}
