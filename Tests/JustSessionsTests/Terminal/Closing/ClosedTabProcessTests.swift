import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Closing a tab ends what it ran, as closing a terminal window does, and leaves nothing in the process table.
/// `kill(pid, 0)` still succeeds for a zombie, so it fails only once the process has ended and been reaped.
@MainActor
struct ClosedTabProcessTests {
    @Test func closingAPlainTerminalEndsItsInteractiveShell() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let tab = makeTab(running: "/bin/zsh", arguments: ["-f", "-i"], in: folder)
        tab.startIfNeeded()
        let shellProcessID = tab.processID
        try #require(shellProcessID > 0)
        // Once started up, an interactive shell ignores SIGTERM, the signal SwiftTerm's `terminate()` sends.
        try await expectEventually { ignoresSIGTERM(shellProcessID) }

        tab.close()

        try await expectEventually { kill(shellProcessID, 0) != 0 }
    }

    @Test func closingATabWhoseProcessEndsRightAwayLeavesNoZombie() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let tab = makeTab(running: "/bin/sleep", arguments: ["60"], in: folder)
        tab.startIfNeeded()
        let processID = tab.processID
        try #require(processID > 0)

        tab.close()

        try await expectEventually { kill(processID, 0) != 0 }
    }

    private func makeTab(running executablePath: String, arguments: [String], in folder: URL) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: nil,
            projectPath: folder.path,
            action: nil,
            displayTitle: "Terminal",
            command: NativeCLICommand(
                executablePath: executablePath,
                arguments: arguments,
                workingDirectory: folder.path,
                environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color"]
            )
        )
    }

    private func ignoresSIGTERM(_ processID: pid_t) -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var managementInformationBase: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, processID]
        guard sysctl(&managementInformationBase, 4, &info, &size, nil, 0) == 0, size > 0 else { return false }
        return info.kp_proc.p_sigignore & (1 << (SIGTERM - 1)) != 0
    }
}
