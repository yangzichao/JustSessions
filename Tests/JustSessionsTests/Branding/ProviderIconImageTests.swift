import AppKit
import Testing

@testable import JustSessions

@MainActor
struct ProviderIconImageTests {
    private static let gridSide: CGFloat = 16
    private static let pixelsPerPoint: CGFloat = 4

    @Test func codexHexagonIsFilledAroundAClearPrompt() throws {
        let image = CodexPromptHexagonIcon.image(size: Self.gridSide)
        #expect(image.isTemplate)
        let bitmap = try Self.render(image)

        #expect(Self.alpha(in: bitmap, atGridX: 8, gridY: 2.5) > 0.9, "the hexagon below its top corner")
        #expect(Self.alpha(in: bitmap, atGridX: 12, gridY: 6) > 0.9, "the hexagon right of the prompt")
        #expect(Self.alpha(in: bitmap, atGridX: 5.9, gridY: 6.8) < 0.1, "the prompt's chevron")
        #expect(Self.alpha(in: bitmap, atGridX: 10, gridY: 10.4) < 0.1, "the prompt's underscore")
        #expect(Self.alpha(in: bitmap, atGridX: 1, gridY: 1) < 0.1, "outside the hexagon's top left side")
    }

    @Test func openCodeRingIsFilledAroundAClearHole() throws {
        let image = OpenCodeBlockRingIcon.image(size: Self.gridSide)
        #expect(image.isTemplate)
        let bitmap = try Self.render(image)

        #expect(Self.alpha(in: bitmap, atGridX: 4.1, gridY: 8) > 0.9, "the ring's left side")
        #expect(Self.alpha(in: bitmap, atGridX: 8, gridY: 13) > 0.9, "the ring's bottom")
        #expect(Self.alpha(in: bitmap, atGridX: 8, gridY: 8) < 0.1, "the hole")
        #expect(Self.alpha(in: bitmap, atGridX: 1, gridY: 8) < 0.1, "left of the ring")
    }

    private static func render(_ image: NSImage) throws -> NSBitmapImageRep {
        let pixelSide = Int(gridSide * pixelsPerPoint)
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixelSide, pixelsHigh: pixelSide, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ))
        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        return bitmap
    }

    private static func alpha(in bitmap: NSBitmapImageRep, atGridX gridX: CGFloat, gridY: CGFloat) -> CGFloat {
        bitmap.colorAt(x: Int(gridX * pixelsPerPoint), y: Int(gridY * pixelsPerPoint))?.alphaComponent ?? 0
    }
}
