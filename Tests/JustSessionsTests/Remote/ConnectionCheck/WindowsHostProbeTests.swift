import Foundation
import Testing

@testable import JustSessions

/// A Windows host prints its `OS` variable; a POSIX shell prints the command's words.
struct WindowsHostProbeTests {
    /// What `cmd.exe`, and PowerShell, print for the probe.
    @Test(arguments: ["Windows_NT $env:OS\r\n", "%OS%\r\nWindows_NT\r\n"])
    func windowsShellsPrintWindowsNT(output: String) {
        #expect(WindowsHostProbe.isWindows(output: output))
    }

    /// The shells a Linux or macOS host logs in with, csh's error included.
    @Test(
        arguments: ["/bin/sh", "/bin/bash", "/bin/zsh", "/bin/dash", "/bin/ksh", "/bin/csh"].filter(FileManager.default.isExecutableFile))
    func posixShellsDoNot(shellPath: String) throws {
        let result = try #require(
            BoundedProcessRunner.result(
                ofExecutable: shellPath,
                arguments: ["-c", WindowsHostProbe.command],
                environment: ["PATH": "/usr/bin:/bin"],
                includesStandardError: true,
                timeout: 10
            ))

        #expect(!result.output.isEmpty)
        #expect(!WindowsHostProbe.isWindows(output: result.output), "\(result.output)")
    }

    @Test func aHostThatCouldNotBeReachedIsNotTakenForWindows() {
        let unreachable = RemoteCommandRecorder().runner(answering: (255, "ssh: connect to host devbox port 22: Connection refused"))
        let silent = RemoteCommandRecorder().runner(answering: nil)

        #expect(!WindowsHostProbe.isWindows("devbox", runner: unreachable, timeout: 1))
        #expect(!WindowsHostProbe.isWindows("devbox", runner: silent, timeout: 1))
    }
}
