/// What draws a tab's terminal and runs its keyboard and screen: SwiftTerm, unless Ghostty is chosen in Settings. A tab
/// keeps the engine it opened with.
enum TerminalEngine: String, CaseIterable, Codable, Identifiable {
    case swiftTerm
    case ghostty

    var id: String { rawValue }

    /// The engine's own name, which is not translated.
    var displayName: String {
        switch self {
        case .ghostty: "Ghostty"
        case .swiftTerm: "SwiftTerm"
        }
    }
}
