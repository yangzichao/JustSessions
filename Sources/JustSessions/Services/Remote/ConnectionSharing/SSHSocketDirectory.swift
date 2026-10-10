import Darwin
import Foundation

/// The folder for shared connections' sockets. `/tmp` is open to every user, so the folder is used only when it is
/// a real folder of this user's that no one else can enter; anyone who connects to a socket uses that connection.
enum SSHSocketDirectory {
    /// The folder, created when missing, or nil when it isn't safe to use.
    static func prepared(at path: String) -> String? {
        if mkdir(path, 0o700) != 0, errno != EEXIST { return nil }
        var status = stat()
        guard lstat(path, &status) == 0,
              status.st_mode & S_IFMT == S_IFDIR,
              status.st_uid == getuid(),
              status.st_mode & 0o077 == 0 else { return nil }
        return path
    }
}
