import Darwin
import Dispatch

/// Waits for a closed tab's process once it exits. SwiftTerm's `terminate()` stops watching the process, and an exited
/// child nobody waits for stays in the process table as a zombie until the app quits.
enum ClosedTabProcessReaper {
    static func reapOnceExited(_ processID: pid_t) {
        // waitpid(0) or waitpid(-1) would reap another tab's process out from under SwiftTerm.
        guard processID > 0 else { return }
        let exitSource = DispatchSource.makeProcessSource(identifier: processID, eventMask: .exit, queue: .global(qos: .utility))
        // The handler keeps the source alive until it has reaped the process. A process that exited before the
        // source was set up still reports its exit.
        exitSource.setEventHandler {
            // macOS can report the exit of a shell that led its terminal's session before the shell can be waited
            // for, so this waits rather than checks. It returns at once for a process that is not the app's child.
            while waitpid(processID, nil, 0) == -1 && errno == EINTR {}
            exitSource.cancel()
        }
        exitSource.activate()
    }
}
