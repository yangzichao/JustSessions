import Foundation

enum TerminalPastedImageFile {
    static let baseName = "pasted-image"
    static let defaultParentFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("JustSessions pasted images", isDirectory: true)

    static func write(_ image: TerminalClipboardImage, in parentFolder: URL) throws -> URL {
        let folder = parentFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let file = folder.appendingPathComponent(baseName).appendingPathExtension(image.fileExtension)
        try image.data.write(to: file)
        return file
    }

    static func remove(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }
}
