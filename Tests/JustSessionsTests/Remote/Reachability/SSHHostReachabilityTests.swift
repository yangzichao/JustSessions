import Foundation
import Testing

@testable import JustSessions

struct SSHHostReachabilityTests {
    /// A name that never resolves, so a command that did connect would print something else.
    static let host = "justsessions-out-of-reach.invalid"
    static let noAnswer = "ssh: connect to host \(host) port 22: Operation timed out\n"

    @Test(arguments: [
        "ssh: Could not resolve hostname \(host): nodename nor servname provided, or not known",
        "ssh: connect to host \(host) port 22: Operation timed out",
        "ssh: connect to host \(host) port 22: Host is down",
        "ssh: connect to host \(host) port 22: Connection refused",
    ])
    func remembersAHostSSHNeverGotTo(output: String) {
        let reachability = SSHHostReachability()

        reachability.noteResult(exitStatus: 255, output: output, on: Self.host)

        #expect(reachability.recentFailureOutput(on: Self.host) == output)
        #expect(reachability.recentFailureOutput(on: "other-host") == nil)
    }

    /// The host answered, so the next command may get through.
    @Test(arguments: [
        (Int32(255), "me@host: Permission denied (publickey,password)."),
        (255, "Host key verification failed."),
        (255, "Timeout, server host not responding."),
        (1, "tmux: no server running"),
        (0, ""),
    ])
    func forgetsTheFailureOnceACommandGetsThrough(exitStatus: Int32, output: String) {
        let reachability = SSHHostReachability()
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: Self.host)

        reachability.noteResult(exitStatus: exitStatus, output: output, on: Self.host)

        #expect(reachability.recentFailureOutput(on: Self.host) == nil)
    }

    @Test func triesTheHostAgainAMinuteAfterTheFailure() {
        let now = LockedValue(Date(timeIntervalSince1970: 1_000))
        let reachability = SSHHostReachability(currentDate: { now.value })
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: Self.host)

        now.update { $0 += SSHHostReachability.failureMemory - 1 }
        #expect(reachability.recentFailureOutput(on: Self.host) == Self.noAnswer)
        now.update { $0 += 1 }
        #expect(reachability.recentFailureOutput(on: Self.host) == nil)
    }

    @Test func forgetsOneHostOrAll() {
        let reachability = SSHHostReachability()
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: Self.host)
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: "second-host")

        reachability.forget(Self.host)
        #expect(reachability.recentFailureOutput(on: Self.host) == nil)
        #expect(reachability.recentFailureOutput(on: "second-host") == Self.noAnswer)

        reachability.forgetAll()
        #expect(reachability.recentFailureOutput(on: "second-host") == nil)
    }

    /// Every command that goes through the runner, such as a refresh's, a folder lookup's, or Reconnect's, fails at
    /// once the way the last one did.
    @Test func aBackgroundCommandToAHostOutOfReachFailsWithoutConnecting() throws {
        let reachability = SSHHostReachability()
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: Self.host)

        let result = try #require(RemoteHostCommandRunner(reachability: reachability).run(Self.host, "true", 30))

        #expect(result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus)
        #expect(result.output == Self.noAnswer)
        #expect(SSHConnectionProblem(sshOutput: result.output) == .noAnswer)
    }

    @Test func theShellStartupCheckDoesNotConnectToAHostOutOfReach() throws {
        let reachability = SSHHostReachability()
        reachability.noteResult(exitStatus: 255, output: Self.noAnswer, on: Self.host)
        let check = RemoteShellStartupCheck(reachability: reachability)

        let result = try #require(check.run(Self.host, "true", 20))

        #expect(result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus)
        #expect(result.output == Self.noAnswer)
        #expect(check.check(host: Self.host) == nil)
    }
}
