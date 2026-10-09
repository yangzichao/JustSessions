import Testing
@testable import JustSessions

/// Adding a host first logs in to it, so the sheet can say why the app can't reach it.
struct RemoteHostConnectionCheckTests {
    @Test func aHostThatAcceptsTheLoginPasses() {
        let recorder = RemoteCommandRecorder()
        let check = RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "")))

        #expect(check.problem(connectingTo: "devbox") == nil)
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(recorder.commands.map(\.command) == ["true"])
    }

    /// Only `ssh`'s own exit status is a failure to connect.
    @Test func aShellStartupErrorStillPasses() {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: (1, "bash: nvm: command not found\n")))

        #expect(check.problem(connectingTo: "devbox") == nil)
    }

    @Test func aFailedLoginSaysWhy() {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: (255, """
            Warning: Permanently added 'devbox' (ED25519) to the list of known hosts.
            me@devbox: Permission denied (publickey).

            """)))

        #expect(check.problem(connectingTo: "devbox") == .loginRefused)
    }

    /// The runner gives up after the check's timeout, as when a login hangs.
    @Test func noResultCountsAsNoAnswer() {
        let check = RemoteHostConnectionCheck(runner: RemoteCommandRecorder().runner(answering: nil))

        #expect(check.problem(connectingTo: "devbox") == .noAnswer)
    }
}
