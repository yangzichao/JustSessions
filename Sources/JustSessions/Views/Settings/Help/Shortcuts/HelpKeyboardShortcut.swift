import SwiftUI

struct HelpKeyboardShortcut {
    let keys: [Text]
    let action: LocalizedStringKey
}

extension HelpKeyboardShortcut {
    init(keys: String..., action: LocalizedStringKey) {
        self.init(keys: keys.map { Text(verbatim: $0) }, action: action)
    }
}

struct HelpKeyboardShortcutGroup {
    let title: LocalizedStringKey
    let shortcuts: [HelpKeyboardShortcut]
}
