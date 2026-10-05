/// Finds, in a program's output, where it subscribes to light and dark theme changes (`CSI ? 2031 h`, undone with
/// `CSI ? 2031 l`) or asks for the current theme (`CSI ? 996 n`), as tmux does when it attaches. SwiftTerm handles
/// neither, so the tab answers them itself. A sequence can arrive split across reads.
struct TerminalThemeReportRequestScanner {
    enum Request: Equatable {
        case subscribe
        case unsubscribe
        case currentTheme
    }

    private enum State {
        case ground
        case escape
        case controlSequenceStart
        case privateParameters
    }

    /// Longer parameters are no request this scanner knows, so it stops collecting them.
    private static let maximumParameterByteCount = 64
    private static let escape: UInt8 = 0x1B

    private var state = State.ground
    private var parameterBytes: [UInt8] = []

    mutating func scan(_ output: ArraySlice<UInt8>) -> [Request] {
        var requests: [Request] = []
        for byte in output {
            switch state {
            case .ground:
                if byte == Self.escape { state = .escape }
            case .escape:
                state = byte == UInt8(ascii: "[") ? .controlSequenceStart : stateAfterOtherByte(byte)
            case .controlSequenceStart:
                if byte == UInt8(ascii: "?") {
                    parameterBytes.removeAll(keepingCapacity: true)
                    state = .privateParameters
                } else {
                    state = stateAfterOtherByte(byte)
                }
            case .privateParameters:
                if byte.isParameterByte {
                    parameterBytes.append(byte)
                    if parameterBytes.count > Self.maximumParameterByteCount { state = .ground }
                } else {
                    if let request = Self.request(parameterBytes: parameterBytes, finalByte: byte) { requests.append(request) }
                    state = stateAfterOtherByte(byte)
                }
            }
        }
        return requests
    }

    private func stateAfterOtherByte(_ byte: UInt8) -> State {
        byte == Self.escape ? .escape : .ground
    }

    private static func request(parameterBytes: [UInt8], finalByte: UInt8) -> Request? {
        let parameters = String(decoding: parameterBytes, as: UTF8.self)
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) }
        switch finalByte {
        case UInt8(ascii: "h"): return parameters.contains(2031) ? .subscribe : nil
        case UInt8(ascii: "l"): return parameters.contains(2031) ? .unsubscribe : nil
        case UInt8(ascii: "n"): return parameters == [996] ? .currentTheme : nil
        default: return nil
        }
    }
}

private extension UInt8 {
    var isParameterByte: Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) || self == UInt8(ascii: ";")
    }
}
