import Foundation

enum ShellQuoting {
    /// Wraps the value in single quotes for a POSIX shell, escaping any single quote inside it.
    static func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
