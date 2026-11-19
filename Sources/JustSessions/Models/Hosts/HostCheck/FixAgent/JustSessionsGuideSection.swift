import Foundation

struct JustSessionsGuideSection: Hashable, Sendable, Identifiable {
    let fileName: String
    let heading: String

    var id: String { "\(fileName)#\(anchor)" }

    /// The heading's anchor on GitHub: lowercase, without punctuation, with a hyphen for each space.
    var anchor: String {
        String(
            heading.lowercased().compactMap { character -> Character? in
                if character == " " { return "-" }
                return character.isLetter || character.isNumber || character == "-" || character == "_" ? character : nil
            })
    }

    func link(gitReference: String) -> URL {
        var components = URLComponents(
            url: AppLinks.gitHubRepositoryURL.appendingPathComponent("blob/\(gitReference)/docs/guides/\(fileName)"),
            resolvingAgainstBaseURL: false
        )!
        components.fragment = anchor
        return components.url!
    }
}

extension JustSessionsGuideSection {
    static let whenSomethingFailsOnSSHHost = Self(fileName: "session-management.md", heading: "When something fails on an SSH host")
    static let shellStartupOnSSHHosts = Self(fileName: "session-management.md", heading: "Shell startup on SSH hosts")
    static let hostsThatAskForPassword = Self(fileName: "session-management.md", heading: "Hosts that ask for a password or code")
    static let terminalPersistence = Self(fileName: "session-storage.md", heading: "Terminal persistence")
    static let cliLaunchAndDiscovery = Self(fileName: "session-storage.md", heading: "CLI launch and discovery")
    static let sshSessionCache = Self(fileName: "session-storage.md", heading: "SSH session cache")

    static let all: [Self] = [
        .whenSomethingFailsOnSSHHost, .terminalPersistence, .shellStartupOnSSHHosts, .hostsThatAskForPassword,
        .cliLaunchAndDiscovery, .sshSessionCache,
    ]

    static func sections(about report: HostCheckReport) -> [Self] {
        let findingIDs = Set(report.findings.filter { $0.status == .problem || $0.status == .warning }.map(\.id))
        let sectionsAboutFindings = findingIDs.flatMap(sections(aboutFindingID:))
        return all.filter { $0 == .whenSomethingFailsOnSSHHost || sectionsAboutFindings.contains($0) }
    }

    private static func sections(aboutFindingID findingID: HostCheckFindingID) -> [Self] {
        switch findingID {
        case .connection: [.hostsThatAskForPassword]
        case .loginShell, .shellStartup: [.shellStartupOnSSHHosts]
        case .tmux: [.terminalPersistence]
        case .rsync, .python3: [.sshSessionCache]
        case .folder, .script, .cli, .otherCLIs: [.cliLaunchAndDiscovery]
        case .system: []
        }
    }
}
