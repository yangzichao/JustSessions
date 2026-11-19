import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct SSHPortForwardsTests {
    static let fakeSSH = """
        #!/bin/sh
        dir=${0%/*}
        mode=connect; control=""; spec=""; target=""; previous=""
        for argument; do
            case "$previous" in
                -S) control="$argument" ;;
                -O) mode="$argument" ;;
                -L) spec="$argument" ;;
                -W) mode=probe; target="$argument" ;;
            esac
            case "$argument" in ControlPath=*) control="${argument#ControlPath=}" ;; esac
            previous="$argument"
        done
        connection_output="${control%/*}/ssh-output"
        case "$mode" in
        connect)
            echo "connect" >> "$dir/requests"
            if [ -e "$dir/connection-fails" ]; then echo "me@devbox: Permission denied (publickey)." >&2; exit 255; fi
            # Waits on one `sleep` rather than looping, which would start a process every few milliseconds for each
            # open connection while the whole suite runs in parallel. `wait` returns at once for the trap.
            trap 'rm -f "$control"; kill $sleeper 2>/dev/null; exit 0' TERM
            echo $$ > "$dir/connection-pid"
            : > "$control"
            sleep 600 &
            sleeper=$!
            wait $sleeper
            ;;
        forward|cancel)
            echo "$mode $spec $control" >> "$dir/requests"
            [ -e "$control" ] || { echo "Control socket connect($control): No such file or directory" >&2; exit 255; }
            if [ "$mode" = forward ] && [ -e "$dir/port-in-use" ]; then
                port=${spec#127.0.0.1:}; port=${port%%:*}
                echo "bind [127.0.0.1]:$port: Address already in use" >> "$connection_output"
                echo "mux_client_forward: forwarding request failed: Port forwarding failed" >&2
                exit 255
            fi
            ;;
        probe)
            echo "probe $target" >> "$dir/requests"
            if [ -e "$dir/forwarding-prohibited" ]; then
                echo "channel 2: open failed: administratively prohibited: open failed" >> "$connection_output"
                echo "Stdio forwarding request failed: Session open refused by peer" >&2
                exit 255
            fi
            if [ -e "$dir/nothing-listens" ]; then
                echo "channel 2: open failed: connect failed: Connection refused" >> "$connection_output"
                echo "Stdio forwarding request failed: Session open refused by peer" >&2
                exit 255
            fi
            ;;
        esac
        """

    @MainActor
    private final class Fixture {
        let scripts: URL
        let socketRoot: String
        let loginConnections = SSHLoginConnections(close: { _, _ in })
        let clock = LockedValue(Date(timeIntervalSince1970: 1_000_000))
        let busyLocalPorts = LockedValue<Set<Int>>([])
        let forwards: SSHPortForwards

        init() throws {
            scripts = try makeTemporaryDirectory()
            socketRoot = makeShortSocketFolder()
            try writeExecutableScript(SSHPortForwardsTests.fakeSSH, to: scripts.appendingPathComponent("ssh"))
            let clock = clock
            let busyLocalPorts = busyLocalPorts
            forwards = SSHPortForwards(
                sshExecutable: scripts.appendingPathComponent("ssh").path,
                socketRoot: socketRoot,
                loginConnections: loginConnections,
                isLocalPortFree: { !busyLocalPorts.value.contains($0) },
                currentDate: { clock.value },
                sleepUntilWakeUp: Self.sleepUntilCancelled
            )
        }

        nonisolated private static func sleepUntilCancelled(_: Duration) async throws {
            while true { try await Task.sleep(for: .seconds(60)) }
        }

        func remove() {
            forwards.endAll()
            try? FileManager.default.removeItem(at: scripts)
            try? FileManager.default.removeItem(atPath: socketRoot)
        }

        var requests: [String] {
            ((try? String(contentsOf: scripts.appendingPathComponent("requests"), encoding: .utf8)) ?? "")
                .split(separator: "\n").map(String.init)
        }

        var connectionCount: Int { requests.filter { $0 == "connect" }.count }

        func set(_ flag: String, _ isSet: Bool = true) {
            let file = scripts.appendingPathComponent(flag)
            if isSet {
                FileManager.default.createFile(atPath: file.path, contents: nil)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }

        var connectionFolders: [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: socketRoot)) ?? []).filter { $0.hasPrefix("forward-") }
        }

        var connectionProcessID: pid_t? {
            (try? String(contentsOf: scripts.appendingPathComponent("connection-pid"), encoding: .utf8))
                .flatMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        func passTime(_ seconds: TimeInterval) {
            clock.update { $0 += seconds }
        }

        func states(on host: String = "devbox") -> [SSHPortForwards.State] {
            forwards.entries(on: host).map(\.state)
        }
    }

    @Test func theConnectionCarriesNoForwardsOfTheUsersConfigAndRunsNothing() {
        let arguments = SSHPortForwardCommands.connectionArguments(host: "devbox", controlPath: "/tmp/s/master")

        #expect(Array(arguments.prefix(2)) == ["-N", "-T"])
        for option in [
            "BatchMode=yes", "ClearAllForwardings=yes", "RemoteCommand=none", "ServerAliveInterval=10",
            "ExitOnForwardFailure=no", "ControlMaster=yes", "ControlPath=/tmp/s/master", "ControlPersist=no",
        ] {
            #expect(arguments.contains(option), "\(option)")
        }
        #expect(Array(arguments.suffix(2)) == ["--", "devbox"])
    }

    @Test func eachForwardIsAddedByAnSSHThatReadsNoConfigAndListensOnlyOnThisMac() {
        let forward = SSHPortForward(host: "me@devbox", localPort: 8080, remotePort: 3000)

        #expect(
            SSHPortForwardCommands.requestArguments(.forward, forward, controlPath: "/tmp/s/master") == [
                "-F", "/dev/null", "-o", "BatchMode=yes", "-S", "/tmp/s/master",
                "-O", "forward", "-L", "127.0.0.1:8080:localhost:3000", "--", "me@devbox",
            ])
        #expect(SSHPortForwardCommands.requestArguments(.cancel, forward, controlPath: "/tmp/s/master")[7] == "cancel")
        #expect(
            SSHPortForwardCommands.probeArguments(forward, controlPath: "/tmp/s/master") == [
                "-F", "/dev/null", "-o", "BatchMode=yes", "-S", "/tmp/s/master",
                "-W", "localhost:3000", "--", "me@devbox",
            ])
        #expect(forward.address == "localhost:8080")
        #expect(forward.browserURL == URL(string: "http://localhost:8080"))
    }

    @Test func onlyARefusalOtherThanNothingListeningFailsTheProbe() {
        #expect(
            SSHPortForwards.refusal(in: "channel 2: open failed: administratively prohibited: open failed")
                == "channel 2: open failed: administratively prohibited: open failed")
        #expect(SSHPortForwards.refusal(in: "channel 2: open failed: connect failed: Connection refused") == nil)
        #expect(SSHPortForwards.refusal(in: "Stdio forwarding request failed: Session open refused by peer") == nil)
    }

    @Test func aHostsForwardsShareOneConnection() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        #expect(await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox") == nil)
        #expect(await fixture.forwards.forward(remotePort: 5173, localPort: 8080, on: "devbox") == nil)

        let folder = try #require(fixture.connectionFolders.first)
        let controlPath = URL(fileURLWithPath: fixture.socketRoot).appendingPathComponent(folder)
            .appendingPathComponent("master").path
        #expect(fixture.connectionFolders.count == 1)
        #expect(
            fixture.requests == [
                "connect",
                "forward 127.0.0.1:3000:localhost:3000 \(controlPath)",
                "probe localhost:3000",
                "forward 127.0.0.1:8080:localhost:5173 \(controlPath)",
                "probe localhost:5173",
            ])
        #expect(
            fixture.forwards.entries(on: "devbox").map(\.forward) == [
                SSHPortForward(host: "devbox", localPort: 3000, remotePort: 3000),
                SSHPortForward(host: "devbox", localPort: 8080, remotePort: 5173),
            ])
        #expect(fixture.states() == [.active, .active])
    }

    @Test func stoppingAForwardCancelsItAndTheLastOneClosesTheConnection() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        _ = await fixture.forwards.forward(remotePort: 5173, localPort: 5173, on: "devbox")
        let processID = try #require(fixture.connectionProcessID)

        fixture.forwards.stop(SSHPortForward(host: "devbox", localPort: 3000, remotePort: 3000))

        try await expectEventually { fixture.requests.contains { $0.hasPrefix("cancel 127.0.0.1:3000:localhost:3000 ") } }
        #expect(fixture.forwards.entries.map(\.forward.localPort) == [5173])
        #expect(kill(processID, 0) == 0)

        fixture.forwards.stop(SSHPortForward(host: "devbox", localPort: 5173, remotePort: 5173))

        #expect(fixture.forwards.entries.isEmpty)
        try await expectEventually { kill(processID, 0) != 0 && fixture.connectionFolders.isEmpty }
    }

    @Test func aPortThisMacForwardsAlreadyOrThatIsNoPortAsksNothing() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        let requests = fixture.requests

        let existing = SSHPortForward(host: "devbox", localPort: 3000, remotePort: 3000)
        let failure = await fixture.forwards.forward(remotePort: 4000, localPort: 3000, on: "other")
        #expect(failure == .localPortForwardedAlready(existing))
        #expect(failure?.message == "Port 3000 on this Mac already forwards to port 3000 on devbox.")
        #expect(await fixture.forwards.forward(remotePort: 0, localPort: 4000, on: "devbox") == .invalidPort)
        #expect(await fixture.forwards.forward(remotePort: 4000, localPort: 65536, on: "devbox") == .invalidPort)
        #expect(fixture.requests == requests)
    }

    @Test func aPortInUseOnThisMacSaysSoWithWhatSSHPrinted() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.set("port-in-use")
        fixture.busyLocalPorts.update { $0.insert(3000) }

        let failure = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")

        #expect(failure == .localPortInUse(port: 3000, sshMessage: "bind [127.0.0.1]:3000: Address already in use"))
        #expect(failure?.message.contains("Another program on this Mac uses port 3000.") == true)
        #expect(fixture.forwards.entries.isEmpty)
        try await expectEventually { fixture.connectionFolders.isEmpty }
    }

    @Test func aRefusedForwardOnAFreePortGivesSSHsReason() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.set("port-in-use")

        let failure = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")

        #expect(failure == .refused(sshMessage: "bind [127.0.0.1]:3000: Address already in use"))
    }

    @Test func aHostThatRefusesForwardingFailsTheForwardWithItsReason() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.set("forwarding-prohibited")

        let failure = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")

        #expect(
            failure
                == .refusedByHost(
                    host: "devbox",
                    sshMessage: "channel 2: open failed: administratively prohibited: open failed"
                ))
        #expect(fixture.requests.contains { $0.hasPrefix("cancel 127.0.0.1:3000:localhost:3000 ") })
        #expect(fixture.forwards.entries.isEmpty)
    }

    @Test func aPortNothingListensOnYetIsForwarded() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.set("nothing-listens")

        #expect(await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox") == nil)
        #expect(fixture.states() == [.active])
    }

    @Test func aHostThatCantBeReachedSaysWhy() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.set("connection-fails")

        let failure = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")

        #expect(failure == .couldNotConnect(host: "devbox", .loginRefused))
        #expect(fixture.forwards.entries.isEmpty)
        #expect(fixture.connectionFolders.isEmpty)
    }

    @Test func aLoggedInHostsForwardsGoThroughTheLoginAndEndOnDisconnect() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let login = try #require(SSHSocketDirectory.makeLoginDirectory(at: fixture.socketRoot))
        let loginControlPath = SSHLoginConnections.controlPath(in: login)
        FileManager.default.createFile(atPath: loginControlPath, contents: nil)
        fixture.loginConnections.add(login, for: "devbox")

        #expect(await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox") == nil)

        #expect(fixture.requests == ["forward 127.0.0.1:3000:localhost:3000 \(loginControlPath)", "probe localhost:3000"])
        #expect(fixture.connectionFolders.isEmpty)

        fixture.forwards.loginEnding(on: "devbox")

        #expect(fixture.forwards.entries.isEmpty)
    }

    @Test func aLoginThatClosesOnItsOwnLeavesItsForwardsReconnecting() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let login = try #require(SSHSocketDirectory.makeLoginDirectory(at: fixture.socketRoot))
        FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: login), contents: nil)
        fixture.loginConnections.add(login, for: "devbox")
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")

        try FileManager.default.removeItem(atPath: SSHLoginConnections.controlPath(in: login))
        fixture.forwards.askDueHosts()

        #expect(fixture.states() == [.reconnecting])
    }

    @Test func aDroppedConnectionIsMadeAgainWithItsForwards() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        let processID = try #require(fixture.connectionProcessID)

        kill(processID, SIGTERM)

        try await expectEventually { fixture.states() == [.reconnecting] }
        #expect(fixture.connectionFolders.isEmpty)
        fixture.forwards.askDueHosts()
        #expect(fixture.connectionCount == 1, "Not due before 2 seconds")

        fixture.passTime(RemoteTabReconnectSchedule.firstTryDelay)
        fixture.forwards.askDueHosts()

        try await expectEventually { fixture.states() == [.active] }
        #expect(fixture.connectionCount == 2)
        #expect(fixture.requests.filter { $0.hasPrefix("forward 127.0.0.1:3000:localhost:3000 ") }.count == 2)
        #expect(fixture.requests.filter { $0.hasPrefix("probe") }.count == 1, "Added again without a probe")
        #expect(fixture.connectionFolders.count == 1)
    }

    @Test func triesThatGiveUpSayWhyAndTheAppComingForwardTriesAgain() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        fixture.set("connection-fails")
        kill(try #require(fixture.connectionProcessID), SIGTERM)
        try await expectEventually { fixture.states() == [.reconnecting] }

        var tries = 0
        while fixture.states() == [.reconnecting], tries < 40 {
            let connections = fixture.connectionCount
            fixture.passTime(RemoteTabReconnectSchedule.longestWait)
            fixture.forwards.askDueHosts()
            try await expectEventually {
                fixture.connectionCount == connections + 1 && fixture.forwards.hostsBeingReconnected.isEmpty
            }
            tries += 1
        }

        let explanation = SSHConnectionProblem.loginRefused.explanation(host: "devbox")
        #expect(fixture.states() == [.connectionLost(explanation)])
        #expect(Double(tries) * RemoteTabReconnectSchedule.longestWait >= RemoteTabReconnectSchedule.tryingPeriod)

        fixture.set("connection-fails", false)
        fixture.forwards.tryAgain()
        #expect(fixture.states() == [.reconnecting])
        fixture.passTime(RemoteTabReconnectSchedule.firstTryDelay)
        fixture.forwards.askDueHosts()

        try await expectEventually { fixture.states() == [.active] }
    }

    @Test func aForwardWhosePortWasTakenMeanwhileSaysSo() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        fixture.set("port-in-use")
        fixture.busyLocalPorts.update { $0.insert(3000) }
        kill(try #require(fixture.connectionProcessID), SIGTERM)
        try await expectEventually { fixture.states() == [.reconnecting] }

        fixture.passTime(RemoteTabReconnectSchedule.firstTryDelay)
        fixture.forwards.askDueHosts()

        let failure = SSHPortForwardFailure.localPortInUse(
            port: 3000,
            sshMessage: "bind [127.0.0.1]:3000: Address already in use"
        )
        try await expectEventually { fixture.states() == [.failed(failure.message)] }
    }

    @Test func removingAHostEndsItsForwardsOnly() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        let devboxProcessID = try #require(fixture.connectionProcessID)
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 4000, on: "other")

        fixture.forwards.stopAll(on: "devbox")

        #expect(fixture.forwards.entries.map(\.forward.host) == ["other"])
        try await expectEventually { kill(devboxProcessID, 0) != 0 && fixture.connectionFolders.count == 1 }
    }

    @Test func quittingEndsEveryConnectionBeforeItReturns() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = await fixture.forwards.forward(remotePort: 3000, localPort: 3000, on: "devbox")
        let processID = try #require(fixture.connectionProcessID)

        fixture.forwards.endAll()

        #expect(kill(processID, 0) != 0)
        #expect(fixture.connectionFolders.isEmpty)
        #expect(fixture.forwards.entries.isEmpty)
    }

    @Test func onlyConnectionsOfAppsNoLongerRunningAreClosedAtLaunch() throws {
        let root = makeShortSocketFolder()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let ours = try #require(SSHSocketDirectory.makePortForwardDirectory(at: root))
        let crashed = try #require(SSHSocketDirectory.makePortForwardDirectory(at: root, processID: try Self.endedProcessID()))
        let crashedLogin = try #require(SSHSocketDirectory.makeLoginDirectory(at: root, processID: try Self.endedProcessID()))
        for directory in [ours, crashed, crashedLogin] {
            FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: directory), contents: nil)
        }
        let closed = LockedValue<[String]>([])

        SSHPortForwardConnection.closeConnectionsOfEndedApps(
            socketRoot: root,
            close: { _, controlPath in
                closed.update { $0.append(controlPath) }
            })

        #expect(closed.value == [SSHLoginConnections.controlPath(in: crashed)])
        #expect(!FileManager.default.fileExists(atPath: crashed.path))
        #expect(FileManager.default.fileExists(atPath: ours.path))
        #expect(FileManager.default.fileExists(atPath: crashedLogin.path), "Logins are closed by their own cleanup")
    }

    private static func endedProcessID() throws -> pid_t {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }
}
