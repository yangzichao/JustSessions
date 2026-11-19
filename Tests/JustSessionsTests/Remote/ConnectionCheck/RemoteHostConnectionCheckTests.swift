import Testing

@testable import JustSessions

struct RemoteHostConnectionCheckTests {
    @Test func aHostThatAcceptsTheLoginPasses() {
        let recorder = RemoteCommandRecorder()
        let check = RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "")))

        #expect(check.problem(connectingTo: "devbox") == nil)
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(recorder.commands.map(\.command) == [WindowsHostProbe.command])
    }

    @Test func aShellStartupErrorStillPasses() {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: (1, "bash: nvm: command not found\n")))

        #expect(check.problem(connectingTo: "devbox") == nil)
    }

    /// Windows' OpenSSH server runs the command in `cmd.exe`, or in PowerShell when that is its default shell.
    @Test(arguments: ["Windows_NT $env:OS\r\n", "%OS%\r\nWindows_NT\r\n"])
    func aWindowsHostIsToldApart(output: String) {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: (0, output)))

        #expect(check.problem(connectingTo: "devbox") == .windowsHost)
    }

    @Test func aFailedLoginSaysWhy() {
        let check = RemoteHostConnectionCheck(
            runner: RemoteCommandRecorder().runner(
                answering: (
                    255,
                    """
                    Warning: Permanently added 'devbox' (ED25519) to the list of known hosts.
                    me@devbox: Permission denied (publickey).

                    """
                )))

        #expect(check.problem(connectingTo: "devbox") == .loginRefused)
    }

    @Test func noResultCountsAsNoAnswer() {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: nil))

        #expect(check.problem(connectingTo: "devbox") == .noAnswer)
    }
}
