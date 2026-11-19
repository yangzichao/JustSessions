enum TerminalEngine: String, CaseIterable, Codable, Identifiable {
    case swiftTerm
    case ghostty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ghostty: "Ghostty"
        case .swiftTerm: "SwiftTerm"
        }
    }
}
