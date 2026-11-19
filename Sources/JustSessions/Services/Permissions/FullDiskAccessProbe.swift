import Foundation

struct FullDiskAccessProbe: Sendable {
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
            if errno == EPERM || errno == EACCES { return .notAllowed }
        }
        return .unknown
    }
}
