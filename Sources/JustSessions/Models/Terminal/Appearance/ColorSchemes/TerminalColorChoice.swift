/// Where terminals take their colors from: the app theme, a preset, or colors imported from iTerm2.
enum TerminalColorChoice: Hashable, Sendable {
    case matchAppTheme
    case preset(TerminalColorPreset)
    case imported
}

extension TerminalColorChoice: RawRepresentable, Codable {
    init?(rawValue: String) {
        switch rawValue {
        case "matchAppTheme": self = .matchAppTheme
        case "imported": self = .imported
        default:
            guard let preset = TerminalColorPreset(rawValue: rawValue) else { return nil }
            self = .preset(preset)
        }
    }

    var rawValue: String {
        switch self {
        case .matchAppTheme: "matchAppTheme"
        case .preset(let preset): preset.rawValue
        case .imported: "imported"
        }
    }
}
