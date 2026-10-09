/// Finds, in a program's output, where it subscribes to light and dark theme changes (`CSI ? 2031 h`, undone with
/// `CSI ? 2031 l`) or asks for the current theme (`CSI ? 996 n`), as tmux does when it attaches. SwiftTerm handles
/// neither, so the tab answers them itself. It also finds where a program asks for the background color
/// (`OSC 11 ; ?`), which SwiftTerm answers. A sequence can arrive split across reads.
struct TerminalThemeReportRequestScanner {
    enum Request: Equatable {
        case subscribe
        case unsubscribe
        case currentTheme
        case backgroundColor
    }

    private enum State {
        case ground
        case escape
        case controlSequenceStart
        case privateParameters
        case operatingSystemCommand
        /// An escape inside an operating system command: the start of its `ESC \` terminator, or of another sequence.
        case operatingSystemCommandEscape
    }

    /// Longer parameters are no request this scanner knows, so it stops collecting them.
    private static let maximumParameterByteCount = 64
    private static let escape: UInt8 = 0x1B
    private static let bell: UInt8 = 0x07
    private static let backgroundColorQuery = Array("11;?".utf8)

    private var state = State.ground
    private var parameterBytes: [UInt8] = []
    private var commandBytes: [UInt8] = []

    mutating func scan(_ output: ArraySlice<UInt8>) -> [Request] {
        output.compactMap { advance(with: $0) }
    }

    private mutating func advance(with byte: UInt8) -> Request? {
        switch state {
        case .ground:
            if byte == Self.escape { state = .escape }
        case .escape:
            if byte == UInt8(ascii: "[") {
                state = .controlSequenceStart
            } else if byte == UInt8(ascii: "]") {
                commandBytes.removeAll(keepingCapacity: true)
                state = .operatingSystemCommand
            } else {
                state = stateAfterOtherByte(byte)
            }
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
                state = stateAfterOtherByte(byte)
                return Self.request(parameterBytes: parameterBytes, finalByte: byte)
            }
        case .operatingSystemCommand:
            if byte == Self.bell {
                state = .ground
                return endOperatingSystemCommand()
            }
            if byte == Self.escape {
                state = .operatingSystemCommandEscape
            } else if commandBytes.count <= Self.backgroundColorQuery.count {
                // Only a short command can be the query; a long one, such as a link, is read to its end uncollected.
                commandBytes.append(byte)
            }
        case .operatingSystemCommandEscape:
            if byte == UInt8(ascii: "\\") {
                state = .ground
                return endOperatingSystemCommand()
            }
            state = .escape
            return advance(with: byte)
        }
        return nil
    }

    private func endOperatingSystemCommand() -> Request? {
        commandBytes == Self.backgroundColorQuery ? .backgroundColor : nil
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
