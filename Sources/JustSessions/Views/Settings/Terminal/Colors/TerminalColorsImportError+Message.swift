import SwiftUI

extension TerminalColorsImportError {
    var localizedMessage: LocalizedStringKey {
        switch self {
        case .iTermSettingsNotFound: "iTerm2 has no saved settings on this Mac."
        case .iTermDefaultProfileNotFound: "Couldn't find iTerm2's default profile. A dynamic profile can't be imported."
        case .unreadableFile: "This file isn't an iTerm2 color preset."
        case .missingColors: "Some colors are missing, such as the text or background color."
        }
    }
}
