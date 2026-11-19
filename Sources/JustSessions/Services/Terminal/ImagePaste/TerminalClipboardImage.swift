import AppKit

/// A clipboard with text pastes the text, so a file copied in Finder, which puts its name there as text, is not one.
struct TerminalClipboardImage: Equatable {
    /// PNG or JPEG, which Claude Code and Codex read. A TIFF, as some apps copy, is converted to PNG.
    let data: Data
    let fileExtension: String

    private static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, jpeg, .tiff]

    static func isOnly(on pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: [.string]) == nil && pasteboard.availableType(from: imageTypes) != nil
    }

    init?(pasteboard: NSPasteboard) {
        guard Self.isOnly(on: pasteboard) else { return nil }
        if let png = pasteboard.data(forType: .png) {
            data = png
            fileExtension = "png"
        } else if let jpeg = pasteboard.data(forType: Self.jpeg) {
            data = jpeg
            fileExtension = "jpg"
        } else if let tiff = pasteboard.data(forType: .tiff),
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        {
            data = png
            fileExtension = "png"
        } else {
            return nil
        }
    }
}
