import Foundation

/// SwiftTerm reports a tab's process ending with the raw status `waitpid` gave it, on macOS where it starts the
/// process with `forkpty`. A tab whose process exited with 2 would otherwise say it exited with 512.
enum ProcessWaitStatus {
    static func exitCode(fromWaitStatus status: Int32) -> Int32? {
        guard status & 0x7f == 0 else { return nil }
        return (status >> 8) & 0xff
    }
}
