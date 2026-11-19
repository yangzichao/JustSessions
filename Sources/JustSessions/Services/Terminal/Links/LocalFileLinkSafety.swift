import Foundation
import UniformTypeIdentifiers

/// Which files and folders on this Mac a link in a terminal may open. A link's target comes from what a program
/// printed, and an OSC 8 hyperlink can show other text than the file it opens, so ⌘-clicking it must never run
/// anything: Launch Services starts an app, a `.jar`, or an executable, and Terminal runs a `.command` or `.tool` script
/// and the commands a `.terminal` file holds.
enum LocalFileLinkSafety {
    static func canOpen(_ fileURL: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.contentTypeKey, .isRegularFileKey, .isExecutableKey]
        guard fileURL.isFileURL, let values = try? fileURL.resourceValues(forKeys: keys) else { return false }
        if let contentType = values.contentType, typesThatRun.contains(where: contentType.conforms(to:)) { return false }
        // An executable without an extension opens in Terminal, which runs it, whatever it holds.
        let isExecutableRegularFile = values.isRegularFile == true && values.isExecutable == true
        return !(isExecutableRegularFile && fileURL.pathExtension.isEmpty)
    }

    /// Terminal declares its two types; `.command` and `.tool` scripts are `com.apple.terminal.shell-script`.
    private static let typesThatRun: [UTType] =
        [.executable, .application]
        + ["com.apple.terminal.shell-script", "com.apple.terminal.settings"].compactMap { UTType($0) }
}
