import Foundation

struct ForwardPortForm: Equatable {
    var remotePortText = ""
    var localPortText = ""

    var remotePort: Int? { Self.port(in: remotePortText) }

    var localPort: Int? {
        localPortText.trimmingCharacters(in: .whitespaces).isEmpty ? remotePort : Self.port(in: localPortText)
    }

    var canForward: Bool { remotePort != nil && localPort != nil }

    mutating func pick(_ port: Int) {
        remotePortText = String(port)
    }

    static func port(in text: String) -> Int? {
        guard let port = Int(text.trimmingCharacters(in: .whitespaces)), SSHPortForward.validPorts.contains(port) else {
            return nil
        }
        return port
    }
}
