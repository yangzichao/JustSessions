import SwiftUI

extension AppAppearanceMode {
    var localizedDisplayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

extension TerminalAppearanceMode {
    var localizedDisplayName: LocalizedStringKey {
        switch self {
        case .matchApp: "Match app"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
