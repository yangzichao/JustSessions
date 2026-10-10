import SwiftUI

/// The pages of Settings. The switcher at its top lists all but Release notes and Send feedback, which open from
/// General's About section or the Help menu.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case permissions
    case help
    case releaseNotes
    case feedback

    /// The pages the switcher lists, in order.
    static let switcherTabs: [SettingsTab] = [.general, .appearance, .permissions, .help]

    var id: String { rawValue }

    /// The switcher segment selected while this page shows. Release notes and Send feedback sit under General.
    var switcherTab: SettingsTab {
        switch self {
        case .releaseNotes, .feedback: .general
        default: self
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .permissions: "Permissions"
        case .help: "Help"
        case .releaseNotes: "Release notes"
        case .feedback: "Send feedback"
        }
    }
}
