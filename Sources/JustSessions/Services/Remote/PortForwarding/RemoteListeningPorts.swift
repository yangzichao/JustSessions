import Foundation

struct RemoteListeningPort: Hashable, Sendable, Identifiable {
    let port: Int
    /// The program that listens, when the host tells: `ss` and `lsof` name only the user's own programs.
    let programName: String?

    var id: Int { port }
}

enum RemoteListeningPorts {
    enum Listing: Equatable, Sendable {
        case listed([RemoteListeningPort])
        case noTool
    }

    static let endMarker = "justsessions-ports-listed"
    static let sectionMarker = "justsessions-ports:"

    /// Run by `sh`, as the login shell may be fish; it has no single quote or backslash. `ss` and `lsof` may be in a
    /// folder the PATH leaves out, as `/usr/sbin` on a macOS host.
    static let script = [
        "PATH=\"$PATH:/usr/sbin:/sbin\"",
        "if command -v ss >/dev/null 2>&1; then echo \(sectionMarker)ss; ss -ltnp 2>/dev/null",
        "else if [ -r /proc/net/tcp ]; then echo \(sectionMarker)proc; cat /proc/net/tcp /proc/net/tcp6 2>/dev/null",
        "elif command -v netstat >/dev/null 2>&1; then echo \(sectionMarker)netstat; netstat -an -p tcp 2>/dev/null",
        "fi",
        "if command -v lsof >/dev/null 2>&1; then echo \(sectionMarker)lsof; lsof +c 0 -nP -iTCP -sTCP:LISTEN 2>/dev/null",
        "fi",
        "fi",
        "echo \(endMarker)",
    ].joined(separator: "; ")

    static func command(on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    static func lookUp(on host: String, runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) -> Listing? {
        guard let result = runner.run(host, command(on: host), 15),
            result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus
        else { return nil }
        return listing(inOutput: result.output)
    }

    static func listing(inOutput output: String) -> Listing? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.contains(endMarker) else { return nil }
        var section: String?
        var foundTool = false
        var programNamesByPort: [Int: String?] = [:]
        for line in lines {
            if line.hasPrefix(sectionMarker) {
                section = String(line.dropFirst(sectionMarker.count))
                foundTool = true
                continue
            }
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            let found: (port: Int, programName: String?)? =
                switch section {
                case "ss": portInSSLine(fields, line: line)
                case "proc": portInProcLine(fields)
                case "netstat": portInNetstatLine(fields)
                case "lsof": portInLsofLine(fields)
                default: nil
                }
            guard let found else { continue }
            if programNamesByPort[found.port] == nil || programNamesByPort[found.port] == .some(nil) {
                programNamesByPort[found.port] = found.programName
            }
        }
        guard foundTool else { return .noTool }
        return .listed(
            programNamesByPort.keys.sorted().map {
                RemoteListeningPort(port: $0, programName: programNamesByPort[$0] ?? nil)
            })
    }

    /// `LISTEN 0 5 127.0.0.1:8080 0.0.0.0:* users:(("python3",pid=2727,fd=3))`: the local address is the first with a
    /// port; the peer's port is `*`.
    private static func portInSSLine(_ fields: [String], line: String) -> (port: Int, programName: String?)? {
        guard let address = fields.lazy.compactMap({ splitAddress($0, separator: ":") }).first,
            reachesLocalhost(address.host)
        else { return nil }
        return (address.port, programName(inSSLine: line))
    }

    /// `0: 0100007F:1F90 00000000:0000 0A …`: the address and port in hexadecimal; state `0A` is listening.
    private static func portInProcLine(_ fields: [String]) -> (port: Int, programName: String?)? {
        guard fields.count > 3, fields[3] == "0A" else { return nil }
        let parts = fields[1].split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1], radix: 16),
            procLocalhostAddresses.contains(parts[0].uppercased())
        else { return nil }
        return (port, nil)
    }

    /// macOS: `tcp4 0 0 127.0.0.1.8080 *.* LISTEN`.
    private static func portInNetstatLine(_ fields: [String]) -> (port: Int, programName: String?)? {
        guard fields.count > 5, fields[0].hasPrefix("tcp"), fields.contains("LISTEN"),
            let address = splitAddress(fields[3], separator: ":") ?? splitAddress(fields[3], separator: "."),
            reachesLocalhost(address.host)
        else { return nil }
        return (address.port, nil)
    }

    /// `python3 2727 me 3u IPv4 787055 0t0 TCP 127.0.0.1:8080 (LISTEN)`.
    private static func portInLsofLine(_ fields: [String]) -> (port: Int, programName: String?)? {
        guard fields.count > 2, fields.last == "(LISTEN)",
            let address = splitAddress(fields[fields.count - 2], separator: ":"),
            reachesLocalhost(address.host)
        else { return nil }
        // lsof writes a space in a program's name as `\x20`.
        return (address.port, fields[0].replacingOccurrences(of: "\\x20", with: " "))
    }

    private static func splitAddress(_ field: String, separator: Character) -> (host: String, port: Int)? {
        guard let index = field.lastIndex(of: separator),
            let port = Int(field[field.index(after: index)...]), SSHPortForward.validPorts.contains(port)
        else { return nil }
        return (String(field[..<index]), port)
    }

    static func reachesLocalhost(_ host: String) -> Bool {
        var address = host.lowercased()
        if address.hasPrefix("["), address.hasSuffix("]") { address = String(address.dropFirst().dropLast()) }
        if let zone = address.firstIndex(of: "%") { address = String(address[..<zone]) }
        return ["*", "0.0.0.0", "::", "127.0.0.1", "::1", "::ffff:127.0.0.1", "::ffff:0.0.0.0"].contains(address)
    }

    /// `/proc/net/tcp`'s addresses that `localhost` reaches, as a little-endian host writes them, and as a big-endian
    /// one does.
    private static let procLocalhostAddresses: Set<String> = [
        "00000000", "0100007F", "7F000001",
        "00000000000000000000000000000000",
        "00000000000000000000000001000000", "00000000000000000000000000000001",
        "0000000000000000FFFF00000100007F", "00000000000000000000FFFF7F000001",
    ]

    private static func programName(inSSLine line: String) -> String? {
        guard let start = line.range(of: "users:((\"") else { return nil }
        let rest = line[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}
