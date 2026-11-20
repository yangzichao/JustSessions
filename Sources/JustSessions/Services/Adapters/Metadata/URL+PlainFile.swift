import Foundation

extension URL {
    /// Resource values describe the item itself, so a symbolic link to a file is not a regular file.
    var isPlainFileNotLinkOrPipe: Bool {
        (try? resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }
}
