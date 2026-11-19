import Foundation
import UniformTypeIdentifiers

/// Which files a ⌘-click opens in the editor chosen in Settings, as iTerm2 sends only text files to its editor: images,
/// PDFs, packages such as an Xcode project, and other files an editor isn't for still open in their default app.
enum FileLinkEditorScope {
    /// A file of a text type, such as source code, Markdown, or JSON; one macOS has no type for, as `main.rs`,
    /// `Dockerfile`, or `.env` may be on a Mac without an app that declares one; or a `.ts` file, which macOS takes
    /// for an MPEG-2 video but which in a CLI's output is TypeScript.
    static func includes(_ fileURL: URL) -> Bool {
        guard let values = try? fileURL.resourceValues(forKeys: [.contentTypeKey, .isPackageKey]),
            values.isPackage != true
        else { return false }
        if fileURL.pathExtension.lowercased() == "ts" { return true }
        guard let contentType = values.contentType else { return false }
        return contentType.conforms(to: .text) || contentType == .data || contentType.isDynamic
    }
}
