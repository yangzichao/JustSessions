import Foundation

enum SSHConnectTimeout {
    static let seconds = 10

    static let options = ["-o", "ConnectTimeout=\(seconds)"]

    static func plus(_ allowance: TimeInterval) -> TimeInterval {
        TimeInterval(seconds) + allowance
    }
}
