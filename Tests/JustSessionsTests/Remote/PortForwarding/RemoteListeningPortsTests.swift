import Darwin
import Foundation
import Testing

@testable import JustSessions

/// The Forward a port sheet offers the ports a host listens on that a forward to `localhost` reaches. The samples are
/// real output: Ubuntu 24.04's `ss` (iproute2 6.1.0), `/proc/net/tcp`, and `lsof` with servers bound to `127.0.0.1`
/// (18765), `::1` (18766), `0.0.0.0` (18767), `::` (18768), and the container's own address (18769), which `localhost`
/// doesn't reach; macOS 26.6's `netstat` and `lsof` with the first four. Three lines are added in the same format to
/// cover more: `ss`'s last, as Ubuntu's systemd-resolved listens, and `netstat`'s last two, a port bound to one of the
/// Mac's addresses and a connection.
struct RemoteListeningPortsTests {
    static let linuxSS = """
        State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
        LISTEN 0      5            0.0.0.0:18767      0.0.0.0:*    users:(("python3",pid=2729,fd=3))
        LISTEN 0      5          127.0.0.1:18765      0.0.0.0:*    users:(("python3",pid=2727,fd=3))
        LISTEN 0      5         172.17.0.3:18769      0.0.0.0:*    users:(("python3",pid=2731,fd=3))
        LISTEN 0      5              [::1]:18766         [::]:*    users:(("python3",pid=2728,fd=3))
        LISTEN 0      5                  *:18768            *:*    users:(("python3",pid=2730,fd=3))
        LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*
        """

    static let linuxProc = """
          sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
           0: 00000000:494F 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 789812 1 0000000000000000 100 0 0 10 0
           1: 0100007F:494D 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 789806 1 0000000000000000 100 0 0 10 0
           2: 030011AC:4951 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 789815 1 0000000000000000 100 0 0 10 0
           3: 030011AC:8C76 685BBD5B:0050 06 00000000:00000000 03:000015DD 00000000     0        0 0 3 0000000000000000
           4: 030011AC:C92A 135CBD5B:0050 06 00000000:00000000 03:000014CB 00000000     0        0 0 3 0000000000000000
          sl  local_address                         remote_address                        st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
           0: 00000000000000000000000000000000:4950 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 789809 1 000000000000
           1: 00000000000000000000000001000000:494E 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 790707 1 000000000000
        """

    /// The test host's `lsof` (4.95) lists only the user's own programs; its `sshd` runs as the user.
    static let linuxLsof = """
        COMMAND   PID   USER   FD   TYPE     DEVICE SIZE/OFF NODE NAME
        sshd        1 ubuntu    3u  IPv4 1118463634      0t0  TCP *:2222 (LISTEN)
        sshd        1 ubuntu    4u  IPv6 1118463635      0t0  TCP *:2222 (LISTEN)
        python3 46602 ubuntu    3u  IPv4 1150230552      0t0  TCP 127.0.0.1:18765 (LISTEN)
        python3 46603 ubuntu    3u  IPv6 1150219870      0t0  TCP *:18766 (LISTEN)
        python3 46604 ubuntu    3u  IPv4 1150231617      0t0  TCP *:18767 (LISTEN)
        """

    static let macOSNetstat = """
        Proto Recv-Q Send-Q  Local Address                                 Foreign Address                               (state)
        tcp6       0      0  ::1.18766              *.*                    LISTEN
        tcp4       0      0  127.0.0.1.18765        *.*                    LISTEN
        tcp46      0      0  *.18768                *.*                    LISTEN
        tcp4       0      0  *.18767                *.*                    LISTEN
        tcp4       0      0  192.168.1.20.5000      *.*                    LISTEN
        tcp4       0      0  192.168.1.20.52814     17.57.146.20.5223      ESTABLISHED
        """

    static let macOSLsof = """
        COMMAND             PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        Python            99825 jyates    4u  IPv4 0x1774fccf22fed5d8      0t0  TCP 127.0.0.1:18765 (LISTEN)
        Python            99826 jyates    4u  IPv6 0x5a8dcf85558cbfef      0t0  TCP [::1]:18766 (LISTEN)
        Python            99827 jyates    4u  IPv4 0x1b51188886f9ee06      0t0  TCP *:18767 (LISTEN)
        Python            99828 jyates    4u  IPv6 0xb1e612aa666a771f      0t0  TCP *:18768 (LISTEN)
        """

    private static func output(_ sections: [(String, String)], finished: Bool = true) -> String {
        let body = sections.map { "\(RemoteListeningPorts.sectionMarker)\($0.0)\n\($0.1)" }.joined(separator: "\n")
        return "Welcome to the host!\n" + body + (finished ? "\n\(RemoteListeningPorts.endMarker)\n" : "\n")
    }

    private static func port(_ port: Int, _ programName: String? = nil) -> RemoteListeningPort {
        RemoteListeningPort(port: port, programName: programName)
    }

    @Test func ssListsEveryPortLocalhostReachesWithItsProgram() {
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("ss", Self.linuxSS)]))
                == .listed([
                    Self.port(18765, "python3"), Self.port(18766, "python3"), Self.port(18767, "python3"), Self.port(18768, "python3"),
                ]))
    }

    @Test func procListsEveryPortAndLsofNamesTheUsersOwn() {
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("proc", Self.linuxProc)]))
                == .listed([
                    Self.port(18765), Self.port(18766), Self.port(18767), Self.port(18768),
                ]))
        // lsof names the user's own programs, and adds a port /proc missed.
        let lsofOfSSHDAndOneServer = Self.linuxLsof.split(separator: "\n").prefix(4).joined(separator: "\n")
        #expect(
            RemoteListeningPorts.listing(
                inOutput: Self.output([
                    ("proc", Self.linuxProc), ("lsof", lsofOfSSHDAndOneServer),
                ]))
                == .listed([
                    Self.port(2222, "sshd"), Self.port(18765, "python3"), Self.port(18766), Self.port(18767), Self.port(18768),
                ]))
    }

    @Test func macOSNetstatListsThePortsAndLsofNamesThem() {
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("netstat", Self.macOSNetstat)]))
                == .listed([
                    Self.port(18765), Self.port(18766), Self.port(18767), Self.port(18768),
                ]))
        #expect(
            RemoteListeningPorts.listing(
                inOutput: Self.output([
                    ("netstat", Self.macOSNetstat), ("lsof", Self.macOSLsof),
                ]))
                == .listed([
                    Self.port(18765, "Python"), Self.port(18766, "Python"), Self.port(18767, "Python"), Self.port(18768, "Python"),
                ]))
    }

    @Test func lsofAloneListsTheUsersOwnPorts() {
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("lsof", Self.linuxLsof)]))
                == .listed([
                    Self.port(2222, "sshd"), Self.port(18765, "python3"), Self.port(18766, "python3"), Self.port(18767, "python3"),
                ]))
        let spacedName = "Code\\x20Helper 812 me 30u IPv4 0x1 0t0 TCP 127.0.0.1:9229 (LISTEN)"
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("lsof", spacedName)]))
                == .listed([
                    Self.port(9229, "Code Helper")
                ]))
    }

    @Test func aHostWithNoToolOrACutOffAnswerSaysSo() {
        #expect(RemoteListeningPorts.listing(inOutput: Self.output([])) == .noTool)
        #expect(RemoteListeningPorts.listing(inOutput: Self.output([("ss", Self.linuxSS)], finished: false)) == nil)
        #expect(
            RemoteListeningPorts.listing(inOutput: Self.output([("ss", "State Recv-Q Send-Q Local Address:Port")]))
                == .listed([]))
    }

    @Test func onlyAddressesLocalhostReachesCount() {
        for address in ["*", "0.0.0.0", "::", "[::]", "127.0.0.1", "::1", "[::1]", "[::ffff:127.0.0.1]"] {
            #expect(RemoteListeningPorts.reachesLocalhost(address), "\(address)")
        }
        for address in ["172.17.0.3", "127.0.0.53%lo", "10.0.0.5", "fe80::1%lo0", "192.168.1.20"] {
            #expect(!RemoteListeningPorts.reachesLocalhost(address), "\(address)")
        }
    }

    /// The script quotes nothing a fish login shell would read otherwise (SSH-54).
    @Test func theScriptHasNoSingleQuoteOrBackslash() {
        #expect(!RemoteListeningPorts.script.contains("'"))
        #expect(!RemoteListeningPorts.script.contains("\\"))
    }

    /// This Mac runs the script as a macOS host would: `netstat`, then `lsof` for the names.
    @Test func theScriptListsAPortThisMacListensOn() throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        try #require(listener >= 0)
        defer { close(listener) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, length) == 0 && listen(listener, 1) == 0 && getsockname(listener, $0, &length) == 0
            }
        }
        try #require(bound)
        let port = Int(UInt16(bigEndian: address.sin_port))

        let result = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteListeningPorts.script],
            timeout: 60
        )

        let output = try #require(result?.output)
        #expect(output.contains("\(RemoteListeningPorts.sectionMarker)netstat"))
        guard case .listed(let ports) = RemoteListeningPorts.listing(inOutput: output) else {
            Issue.record("Not listed: \(output.suffix(2000))")
            return
        }
        let listed = try #require(ports.first { $0.port == port })
        #expect(listed.programName != nil, "lsof names this test's own process")
    }
}
