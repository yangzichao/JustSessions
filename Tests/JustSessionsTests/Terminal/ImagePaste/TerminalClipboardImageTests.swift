import AppKit
import Testing

@testable import JustSessions

@MainActor
struct TerminalClipboardImageTests {
    @Test func aPNGWithNoTextIsTakenAsItIs() throws {
        let png = makePNGData()
        let pasteboard = NSPasteboard.holding([.png: png, .tiff: NSImage(data: png)!.tiffRepresentation!])
        defer { pasteboard.releaseGlobally() }

        #expect(TerminalClipboardImage.isOnly(on: pasteboard))
        let image = try #require(TerminalClipboardImage(pasteboard: pasteboard))
        #expect(image.data == png)
        #expect(image.fileExtension == "png")
    }

    @Test func aJPEGKeepsItsKind() throws {
        let jpeg = NSBitmapImageRep(data: makePNGData())!.representation(using: .jpeg, properties: [:])!
        let pasteboard = NSPasteboard.holding([NSPasteboard.PasteboardType("public.jpeg"): jpeg])
        defer { pasteboard.releaseGlobally() }

        let image = try #require(TerminalClipboardImage(pasteboard: pasteboard))
        #expect(image.data == jpeg)
        #expect(image.fileExtension == "jpg")
    }

    /// Claude Code and Codex read no TIFF.
    @Test func aTIFFIsConvertedToPNG() throws {
        let png = makePNGData()
        let pasteboard = NSPasteboard.holding([.tiff: NSImage(data: png)!.tiffRepresentation!])
        defer { pasteboard.releaseGlobally() }

        let image = try #require(TerminalClipboardImage(pasteboard: pasteboard))
        #expect(image.fileExtension == "png")
        let bitmap = try #require(NSBitmapImageRep(data: image.data))
        #expect(bitmap.pixelsWide == 6 && bitmap.pixelsHigh == 4)
        #expect(image.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    /// A file copied in Finder puts its name on the clipboard as text, beside its icon.
    @Test func anImageWithTextPastesTheText() {
        let icon = NSImage(data: makePNGData())!.tiffRepresentation!
        let pasteboard = NSPasteboard.holding([.tiff: icon, .string: Data("shot.png".utf8)])
        defer { pasteboard.releaseGlobally() }

        #expect(!TerminalClipboardImage.isOnly(on: pasteboard))
        #expect(TerminalClipboardImage(pasteboard: pasteboard) == nil)
    }

    @Test func noImageIsNone() {
        let empty = NSPasteboard.withUniqueName()
        let text = NSPasteboard.holding([.string: Data("hello".utf8)])
        defer {
            empty.releaseGlobally()
            text.releaseGlobally()
        }

        #expect(!TerminalClipboardImage.isOnly(on: empty))
        #expect(!TerminalClipboardImage.isOnly(on: text))
        #expect(TerminalClipboardImage(pasteboard: empty) == nil)
    }

}
