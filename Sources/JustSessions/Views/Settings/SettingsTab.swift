import SwiftUI

/// The pages of Settings, in the order the switcher at its top lists them.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case permissions

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .permissions: "Permissions"
        }
    }
}
