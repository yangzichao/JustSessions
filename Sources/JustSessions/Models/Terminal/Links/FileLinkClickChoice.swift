enum FileLinkClickChoice: Hashable {
    case defaultApp
    case askEachTime
    case editor(name: String)

    static let userDefaultsKey = "fileLinkClickChoice"

    var storedValue: String {
        switch self {
        case .defaultApp: "defaultApp"
        case .askEachTime: "askEachTime"
        case .editor(let name): Self.editorPrefix + name
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case "defaultApp": self = .defaultApp
        case "askEachTime": self = .askEachTime
        default:
            guard storedValue.hasPrefix(Self.editorPrefix) else { return nil }
            let name = String(storedValue.dropFirst(Self.editorPrefix.count))
            guard !name.isEmpty else { return nil }
            self = .editor(name: name)
        }
    }

    private static let editorPrefix = "editor:"
}
