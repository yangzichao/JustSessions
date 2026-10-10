import AppKit
import GhosttyTerminal

/// An `AppTerminalView` in a window that is never shown, fed output through an in-memory session.
@MainActor
final class GhosttyTestTerminal {
    let window: NSWindow
    let view: AppTerminalView
    let session: InMemoryTerminalSession
    /// What the terminal has sent to its process, such as the bytes of a key.
    private let sentBytes = SentBytes()
    private var lastKeyEventTime: TimeInterval = 0

    init(controller: TerminalController, appearance: NSAppearance.Name) {
        let frame = NSRect(x: 0, y: 0, width: 240, height: 80)
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // Otherwise the snapshot would take the color space of the screen the window is on; see `drawnColors()`.
        window.colorSpace = .displayP3
        session = InMemoryTerminalSession(write: { [sentBytes] in sentBytes.append($0) }, resize: { _ in })
        view = AppTerminalView(frame: frame)
        view.appearance = NSAppearance(named: appearance)
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        view.controller = controller
        window.contentView = view
    }

    deinit {
        MainActor.assumeIsolated {
            window.contentView = nil
            window.close()
        }
    }

    func show(_ output: String) {
        session.receive(output)
        _ = session.waitForPendingOutput()
    }

    /// The bytes the terminal sends for `key`, delivered as AppKit delivers a key: as a key equivalent first, and
    /// then, unless the view took it as one, as a key down. Ghostty sends from its own thread, so an `x` typed after
    /// the key marks where the key's bytes end, even when it sends none.
    func bytesSent(pressing key: USKey) async throws -> [UInt8] {
        _ = sentBytes.take()
        press(key)
        press(.x)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        var bytes: [UInt8] = []
        while bytes.last != UInt8(ascii: "x"), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            bytes += sentBytes.take()
        }
        return bytes.last == UInt8(ascii: "x") ? Array(bytes.dropLast()) : bytes
    }

    func press(_ key: USKey) {
        let keyDown = keyEvent(key, .keyDown)
        if !view.performKeyEquivalent(with: keyDown) {
            view.keyDown(with: keyDown)
        }
        view.keyUp(with: keyEvent(key, .keyUp))
    }

    /// Each event gets its own time: the view takes a key equivalent at the same time as the last one as its echo.
    func keyEvent(_ key: USKey, _ type: NSEvent.EventType) -> NSEvent {
        lastKeyEventTime += 1
        return NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: key.modifierFlags, timestamp: lastKeyEventTime,
            windowNumber: window.windowNumber, context: nil, characters: key.characters,
            charactersIgnoringModifiers: key.characters, isARepeat: false, keyCode: key.keyCode
        )!
    }

    /// How many pixels of the snapshot are each color, in sRGB. Ghostty draws in Display P3. The snapshot holds the
    /// drawn values and is labeled with the window's color space, which is Display P3 here, so converting from the
    /// snapshot's own color space gives sRGB. Were the window left on the screen's color space, the snapshot would
    /// still hold Display P3 values on a Display P3 screen, but its label, and so the conversion, would depend on the
    /// screen.
    func drawnColors() -> [UInt32: Int] {
        guard let representation = view.snapshotImage()?.representations.first as? NSBitmapImageRep else { return [:] }
        var drawnColors: [UInt32: Int] = [:]
        var pixel = [Int](repeating: 0, count: max(representation.samplesPerPixel, 4))
        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                representation.getPixel(&pixel, atX: x, y: y)
                drawnColors[UInt32(pixel[0] << 16 | pixel[1] << 8 | pixel[2]), default: 0] += 1
            }
        }
        var sRGBColors: [UInt32: Int] = [:]
        for (drawnColor, count) in drawnColors {
            sRGBColors[Self.sRGB(drawnColor, from: representation.colorSpace), default: 0] += count
        }
        return sRGBColors
    }

    private static func sRGB(_ color: UInt32, from colorSpace: NSColorSpace) -> UInt32 {
        let components = [16, 8, 0].map { CGFloat((color >> UInt32($0)) & 0xFF) / 255 } + [1]
        guard let converted = NSColor(colorSpace: colorSpace, components: components, count: 4).usingColorSpace(.sRGB) else { return color }
        return [converted.redComponent, converted.greenComponent, converted.blueComponent]
            .reduce(0) { $0 << 8 | UInt32((min(max($1, 0), 1) * 255).rounded()) }
    }
}

/// Collects what Ghostty's thread sends.
private final class SentBytes: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: [UInt8] = []

    func append(_ data: Data) {
        lock.withLock { bytes += data }
    }

    func take() -> [UInt8] {
        lock.withLock {
            defer { bytes = [] }
            return bytes
        }
    }
}

/// A key as the US keyboard layout gives it to AppKit.
struct USKey: CustomStringConvertible {
    let description: String
    let keyCode: UInt16
    let characters: String
    let modifierFlags: NSEvent.ModifierFlags

    static let x = USKey(description: "X", keyCode: 7, characters: "x", modifierFlags: [])
}

extension [UInt32: Int] {
    /// Whether at least `pixels` pixels are within a step or two of `color`.
    func covers(_ color: UInt32, pixels: Int) -> Bool {
        self.pixels(near: color) >= pixels
    }

    /// How many pixels are within a step or two of `color`, which color conversion can be off by.
    func pixels(near color: UInt32) -> Int {
        filter { drawn, _ in
            [16, 8, 0].allSatisfy { shift in abs(Int((drawn >> UInt32(shift)) & 0xFF) - Int((color >> UInt32(shift)) & 0xFF)) <= 2 }
        }.values.reduce(0, +)
    }
}
