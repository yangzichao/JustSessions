import Foundation

enum HostCheckFindingID: Hashable, Sendable, Codable, RawRepresentable {
    case connection
    case shellStartup
    case script
    case loginShell
    case system
    case rsync
    case folder
    case tmux
    case cli(ConversationProvider)
    case otherCLIs
    case python3

    static var all: [Self] {
        [.connection, .shellStartup, .script, .loginShell, .system, .rsync, .folder, .tmux]
            + ConversationProvider.allCases.map(Self.cli) + [.otherCLIs, .python3]
    }

    var rawValue: String {
        switch self {
        case .connection: "connection"
        case .shellStartup: "shell-startup"
        case .script: "script"
        case .loginShell: "login-shell"
        case .system: "system"
        case .rsync: "rsync"
        case .folder: "folder"
        case .tmux: "tmux"
        case .cli(let provider): "cli-" + provider.executableName
        case .otherCLIs: "cli-others"
        case .python3: "python3"
        }
    }

    var isAboutOneSessionRatherThanTheHost: Bool {
        switch self {
        case .folder: true
        case .connection, .shellStartup, .script, .loginShell, .system, .rsync, .tmux, .cli, .otherCLIs, .python3: false
        }
    }

    init?(rawValue: String) {
        guard let id = Self.all.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = id
    }
}
