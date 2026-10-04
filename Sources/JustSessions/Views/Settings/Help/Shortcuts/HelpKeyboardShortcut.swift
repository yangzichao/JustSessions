import SwiftUI

/// One line of the shortcut list in Help: the keys, then what they do. Several keys are alternatives.
struct HelpKeyboardShortcut {
    let keys: [Text]
    let action: LocalizedStringKey
}

extension HelpKeyboardShortcut {
    /// Keys spelled in symbols and key names, which read the same in every language.
    init(keys: String..., action: LocalizedStringKey) {
        self.init(keys: keys.map { Text(verbatim: $0) }, action: action)
    }
}

/// The shortcuts that apply in one part of the window.
struct HelpKeyboardShortcutGroup {
    let title: LocalizedStringKey
    let shortcuts: [HelpKeyboardShortcut]
}
