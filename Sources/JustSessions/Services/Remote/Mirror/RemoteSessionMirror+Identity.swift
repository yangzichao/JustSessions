import CryptoKit
import Foundation

extension RemoteSessionMirror {
    /// Fixed-length ASCII avoids punctuation, case-folding, and Unicode-normalization collisions on macOS disks.
    static func directoryName(forHost host: String) -> String {
        "host-v2-" + SHA256.hash(data: Data(host.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
