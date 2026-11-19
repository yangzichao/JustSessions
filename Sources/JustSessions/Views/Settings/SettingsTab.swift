import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case permissions
    case help
    case releaseNotes

    static let switcherTabs: [SettingsTab] = [.general, .appearance, .permissions, .help]

    var id: String { rawValue }

    var switcherTab: SettingsTab {
        self == .releaseNotes ? .general : self
    }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .permissions: "Permissions"
        case .help: "Help"
        case .releaseNotes: "Release notes"
        }
    }
}
