import CryptoKit
import Foundation

extension RemoteSessionMirror {
    /// Fixed-length ASCII avoids punctuation, case-folding, and Unicode-normalization collisions on macOS disks.
    static func directoryName(forHost host: String) -> String {
        "host-v2-" + SHA256.hash(data: Data(host.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static let migrationLock = NSLock()

    func migrateLegacyMirrors(for configuredHosts: [String]) {
        Self.migrationLock.withLock {
            let groups = Dictionary(grouping: Set(configuredHosts)) { Self.legacyDirectoryName(forHost: $0).lowercased() }
            for host in configuredHosts {
                let oldName = Self.legacyDirectoryName(forHost: host)
                guard host.unicodeScalars.allSatisfy(\.isASCII), oldName == host,
                    !oldName.lowercased().hasPrefix("host-v2-"), groups[oldName.lowercased()]?.count == 1
                else { continue }
                let legacy = cacheRoot.appendingPathComponent(oldName, isDirectory: true)
                let destination = cacheRoot.appendingPathComponent(Self.directoryName(forHost: host), isDirectory: true)
                guard let values = try? legacy.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                    values.isDirectory == true, values.isSymbolicLink != true,
                    !FileManager.default.fileExists(atPath: destination.path)
                else { continue }
                try? FileManager.default.moveItem(at: legacy, to: destination)
            }
        }
    }

    static func legacyDirectoryName(forHost host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_@"))
        let name = String(host.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return name.allSatisfy { $0 == "." } ? "_" + name : name
    }
}
