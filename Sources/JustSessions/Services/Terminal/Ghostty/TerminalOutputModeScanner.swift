/// Each screen keeps its own kitty keyboard flags, as in Ghostty and SwiftTerm: `CSI > n u` pushes flags `n`, `CSI < n u`
/// pops `n` entries, and `CSI = n ; m u` sets (`m` = 1), adds (2) or removes (3) flags `n`. These follow Ghostty's
/// parsing and stack, which is what encodes the key.
struct TerminalOutputModeScanner {
    private enum State {
        case ground
        case escape
        case controlSequenceStart
        case parameters(marker: UInt8)
    }

    private static let maximumParameterByteCount = 64
    private static let escape: UInt8 = 0x1B
    private static let alternateScreenModes: Set<Int> = [1049, 1047, 47]
    private static let bracketedPasteMode = 2004
    private static let markers: Set<UInt8> = [UInt8(ascii: "?"), UInt8(ascii: ">"), UInt8(ascii: "<"), UInt8(ascii: "=")]

    private(set) var isOnAlternateScreen = false
    private(set) var isBracketedPasteOn = false
    private var mainScreenKittyFlags = KittyKeyboardFlagStack()
    private var alternateScreenKittyFlags = KittyKeyboardFlagStack()
    private var state = State.ground
    private var parameterBytes: [UInt8] = []

    var hasKittyKeyboardFlags: Bool {
        (isOnAlternateScreen ? alternateScreenKittyFlags : mainScreenKittyFlags).current != 0
    }

    mutating func scan(_ output: ArraySlice<UInt8>) {
        for byte in output {
            switch state {
            case .ground:
                if byte == Self.escape { state = .escape }
            case .escape:
                if byte == UInt8(ascii: "c") {
                    reset()
                    state = .ground
                } else {
                    state = byte == UInt8(ascii: "[") ? .controlSequenceStart : stateAfterOtherByte(byte)
                }
            case .controlSequenceStart:
                if Self.markers.contains(byte) {
                    parameterBytes.removeAll(keepingCapacity: true)
                    state = .parameters(marker: byte)
                } else {
                    state = stateAfterOtherByte(byte)
                }
            case .parameters(let marker):
                if byte.isParameterByte {
                    parameterBytes.append(byte)
                    if parameterBytes.count > Self.maximumParameterByteCount { state = .ground }
                } else {
                    apply(marker: marker, finalByte: byte)
                    state = stateAfterOtherByte(byte)
                }
            }
        }
    }

    private mutating func reset() {
        isOnAlternateScreen = false
        isBracketedPasteOn = false
        mainScreenKittyFlags = KittyKeyboardFlagStack()
        alternateScreenKittyFlags = KittyKeyboardFlagStack()
    }

    private mutating func apply(marker: UInt8, finalByte: UInt8) {
        // As in Ghostty's parser: an empty number counts as 0, except after the last `;`, which adds no parameter, and
        // no parameters at all is an empty list.
        var fields = String(decoding: parameterBytes, as: UTF8.self).split(separator: ";", omittingEmptySubsequences: false)
        if fields.last?.isEmpty == true { fields.removeLast() }
        let parameters = fields.map { Int($0.isEmpty ? "0" : $0) ?? .max }
        switch (marker, finalByte) {
        case (UInt8(ascii: "?"), UInt8(ascii: "h")): applyPrivateModes(parameters, isSet: true)
        case (UInt8(ascii: "?"), UInt8(ascii: "l")): applyPrivateModes(parameters, isSet: false)
        case (UInt8(ascii: ">"), UInt8(ascii: "u")): pushKittyFlags(parameters)
        case (UInt8(ascii: "<"), UInt8(ascii: "u")): popKittyFlags(parameters)
        case (UInt8(ascii: "="), UInt8(ascii: "u")): setKittyFlags(parameters)
        default: break
        }
    }

    private mutating func applyPrivateModes(_ modes: [Int], isSet: Bool) {
        if modes.contains(Self.bracketedPasteMode) { isBracketedPasteOn = isSet }
        if modes.contains(where: Self.alternateScreenModes.contains) { isOnAlternateScreen = isSet }
    }

    /// Ghostty ignores flags above the protocol's five bits, and pushes 0 unless exactly one number is given.
    private mutating func pushKittyFlags(_ parameters: [Int]) {
        let flags = parameters.count == 1 ? KittyKeyboardFlagStack.flags(parameters[0]) : 0
        guard let flags else { return }
        updateKittyFlags { $0.push(flags) }
    }

    private mutating func popKittyFlags(_ parameters: [Int]) {
        let count = parameters.count == 1 ? parameters[0] : 1
        updateKittyFlags { $0.pop(count) }
    }

    private mutating func setKittyFlags(_ parameters: [Int]) {
        let flags = parameters.isEmpty ? 0 : KittyKeyboardFlagStack.flags(parameters[0])
        guard let flags else { return }
        let mode = parameters.count >= 2 ? parameters[1] : 1
        updateKittyFlags { $0.set(flags, mode: mode) }
    }

    private mutating func updateKittyFlags(_ update: (inout KittyKeyboardFlagStack) -> Void) {
        if isOnAlternateScreen {
            update(&alternateScreenKittyFlags)
        } else {
            update(&mainScreenKittyFlags)
        }
    }

    private func stateAfterOtherByte(_ byte: UInt8) -> State {
        byte == Self.escape ? .escape : .ground
    }
}

/// Ghostty's stack of kitty keyboard flags (`FlagStack` in `src/terminal/kitty/key.zig`): eight entries in a ring, the
/// current flags in the top one. A push past the eighth drops the oldest; a pop of eight or more clears them all.
private struct KittyKeyboardFlagStack {
    private static let capacity = 8

    private var entries = [UInt8](repeating: 0, count: capacity)
    private var top = 0

    var current: UInt8 { entries[top] }

    static func flags(_ number: Int) -> UInt8? {
        (0...31).contains(number) ? UInt8(number) : nil
    }

    mutating func push(_ flags: UInt8) {
        top = (top + 1) % Self.capacity
        entries[top] = flags
    }

    mutating func pop(_ count: Int) {
        guard count < Self.capacity else {
            self = KittyKeyboardFlagStack()
            return
        }
        for _ in 0..<max(count, 0) {
            entries[top] = 0
            top = (top + Self.capacity - 1) % Self.capacity
        }
    }

    mutating func set(_ flags: UInt8, mode: Int) {
        switch mode {
        case 1: entries[top] = flags
        case 2: entries[top] |= flags
        case 3: entries[top] &= ~flags
        default: break
        }
    }
}

extension UInt8 {
    fileprivate var isParameterByte: Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) || self == UInt8(ascii: ";")
    }
}
