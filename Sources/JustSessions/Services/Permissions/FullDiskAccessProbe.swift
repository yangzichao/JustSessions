import Foundation

/// Tells whether the app has Full Disk Access by opening a file that only Full Disk Access can read. macOS never asks
/// for Full Disk Access, so a refused open shows no prompt.
struct FullDiskAccessProbe: Sendable {
    /// The first of these that exists decides.
    var protectedFiles: [String] = [
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
        NSHomeDirectory() + "/Library/Safari/Bookmarks.plist",
    ]

    func status() -> AppPermissionStatus {
        for path in protectedFiles {
            let descriptor = open(path, O_RDONLY)
            if descriptor >= 0 {
                close(descriptor)
                return .allowed
            }
            // macOS refuses with EPERM. A missing file says nothing, so the next one decides.
            if errno == EPERM || errno == EACCES { return .notAllowed }
        }
        return .unknown
    }
}
