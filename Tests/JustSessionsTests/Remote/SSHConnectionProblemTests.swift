import Testing
@testable import JustSessions

/// Real OpenSSH messages, as `ssh` prints them to standard error.
struct SSHConnectionProblemTests {
    @Test(arguments: [
        ("ssh: Could not resolve hostname devbox: nodename nor servname provided, or not known", SSHConnectionProblem.hostNotFound),
        ("ssh: connect to host devbox.example.com port 22: Operation timed out", .noAnswer),
        ("ssh: connect to host 10.0.0.2 port 22: Connection timed out", .noAnswer),
        ("ssh: connect to host 10.0.0.2 port 22: No route to host", .noAnswer),
        ("ssh: connect to host 10.0.0.2 port 22: Network is unreachable", .noAnswer),
        ("ssh: connect to host devbox port 22: Connection refused", .refused),
        ("Timeout, server devbox not responding.", .connectionLost),
        ("client_loop: send disconnect: Broken pipe", .connectionLost),
        ("Connection reset by 10.0.0.2 port 22", .connectionLost),
        ("kex_exchange_identification: read: Connection reset by peer", .connectionLost),
        ("Connection closed by 10.0.0.2 port 22", .connectionLost),
        ("Connection to devbox closed by remote host.", .connectionLost),
        ("me@devbox: Permission denied (publickey,password).", .loginRefused),
        ("Received disconnect from 10.0.0.2 port 22:2: Too many authentication failures", .loginRefused),
        ("Host key verification failed.", .hostKeyNotTrusted),
        ("@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @", .hostKeyNotTrusted),
        ("Bad owner or permissions on /Users/me/.ssh/config", .other(sshMessage: "Bad owner or permissions on /Users/me/.ssh/config")),
    ])
    func classifiesOpenSSHMessages(message: String, problem: SSHConnectionProblem) {
        #expect(SSHConnectionProblem(sshMessage: message) == problem)
        #expect(SSHConnectionProblem(sshMessage: message.uppercased()) == problem || problem == .other(sshMessage: message))
    }

    @Test func picksTheLineThatNamesTheProblemOverWhatFollowsIt() {
        #expect(SSHConnectionProblem.tellingLine(inOutput: """
            Received disconnect from 10.0.0.2 port 22:2: Too many authentication failures\r
            Disconnected from 10.0.0.2 port 22\r

            """) == "Received disconnect from 10.0.0.2 port 22:2: Too many authentication failures")
        #expect(SSHConnectionProblem.tellingLine(inOutput: """
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
            Offending ED25519 key in /Users/me/.ssh/known_hosts:12
            Host key verification failed.
            """) == "Host key verification failed.")
        // Output of the remote command before the connection dropped does not hide ssh's own message.
        #expect(SSHConnectionProblem.tellingLine(inOutput: "rm: cannot remove 'x': Permission denied (os error 13)\nTimeout, server devbox not responding.\n")
            == "Timeout, server devbox not responding.")
    }

    /// The remote command's own output comes before ssh's; it must not be taken for ssh's reason.
    @Test func aRemoteCommandsErrorIsNotTakenForSSHs() {
        #expect(SSHConnectionProblem(sshMessage: "rm: cannot remove 'x': Permission denied") == .other(sshMessage: "rm: cannot remove 'x': Permission denied"))
        #expect(SSHConnectionProblem.tellingLine(inOutput: """
            Traceback (most recent call last):
              File "<stdin>", line 3, in <module>
            ConnectionRefusedError: [Errno 111] Connection refused
            removing session files
            still removing
            ssh_dispatch_run_fatal: Connection to 10.0.0.2 port 22: message authentication code incorrect
            """) == "ssh_dispatch_run_fatal: Connection to 10.0.0.2 port 22: message authentication code incorrect")
    }

    /// What macOS's `rsync` printed when the `ssh` it ran failed; the copy of a host's sessions reports the cause.
    @Test(arguments: [
        ("ssh: Could not resolve hostname devbox: nodename nor servname provided, or not known\nrsync(51043): error: unexpected end of file\n",
         SSHConnectionProblem.hostNotFound),
        ("ssh: connect to host 127.0.0.1 port 1: Connection refused\nrsync(51048): error: unexpected end of file\n", .refused),
        ("No ED25519 host key is known for devbox and you have requested strict checking.\nHost key verification failed.\n"
            + "rsync(51051): error: unexpected end of file\n", .hostKeyNotTrusted),
        ("", .other(sshMessage: "ssh exited without saying why.")),
    ])
    func classifiesTheOutputOfRsyncsSSH(output: String, problem: SSHConnectionProblem) {
        #expect(SSHConnectionProblem(sshOutput: output) == problem)
    }

    @Test func keepsTheLastLineWithWordsWhenNoneNamesAKnownProblem() {
        #expect(SSHConnectionProblem.tellingLine(inOutput: "Warning: something\nBad owner or permissions on /Users/me/.ssh/config\n\n")
            == "Bad owner or permissions on /Users/me/.ssh/config")
        #expect(SSHConnectionProblem.tellingLine(inOutput: "\n  \n@@@\n") == nil)
        let longLine = SSHConnectionProblem.tellingLine(inOutput: String(repeating: "x", count: 500))
        #expect(longLine?.count == SSHConnectionProblem.maximumMessageLength)
        #expect(longLine?.hasSuffix("…") == true)
    }

    @Test func explainsWhatHappenedAndWhatToDo() {
        #expect(SSHConnectionProblem.hostNotFound.explanation(host: "devbox")
            == "devbox couldn't be found. Check the host name and your network or VPN.")
        #expect(SSHConnectionProblem.noAnswer.explanation(host: "devbox") == "devbox didn't answer. Check your network or VPN.")
        #expect(SSHConnectionProblem.refused.explanation(host: "devbox")
            == "devbox refused the SSH connection. Check that SSH is running on it.")
        #expect(SSHConnectionProblem.connectionLost.explanation(host: "devbox")
            == "The connection to devbox was lost, for example because the Mac slept or the network changed.")
        #expect(SSHConnectionProblem.loginRefused.explanation(host: "devbox")
            == "devbox didn't accept the SSH login without a password. Check that “ssh devbox” works in Terminal without asking for a password.")
        #expect(SSHConnectionProblem.hostKeyNotTrusted.explanation(host: "devbox")
            == "devbox's host key has changed or isn't trusted. Connect once with “ssh devbox” in Terminal to check it.")
        #expect(SSHConnectionProblem.other(sshMessage: "Bad owner").explanation(host: "devbox") == "Couldn't connect to devbox: Bad owner")
    }

    @Test func onlyALoginOrHostKeyProblemNeedsAFixBeforeTryingAgain() {
        #expect(SSHConnectionProblem.connectionLost.isLikelyTemporary)
        #expect(SSHConnectionProblem.hostNotFound.isLikelyTemporary)
        #expect(!SSHConnectionProblem.loginRefused.isLikelyTemporary)
        #expect(!SSHConnectionProblem.hostKeyNotTrusted.isLikelyTemporary)
        #expect(UnresponsiveSSHHost.didNotRespondInTime(host: "devbox").isLikelyTemporary)
    }
}
