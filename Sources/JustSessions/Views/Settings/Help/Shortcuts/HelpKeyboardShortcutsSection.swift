import SwiftUI

struct HelpKeyboardShortcutsSection: View {
    var body: some View {
        HelpSection(title: "Keyboard shortcuts") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Array(HelpKeyboardShortcutGroup.all.enumerated()), id: \.offset) { groupIndex, group in
                    Text(group.title)
                        .font(ThemeFont.fieldLabel)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .padding(.top, groupIndex > 0 ? 8 : 0)
                        .gridCellColumns(2)
                    ForEach(group.shortcuts.indices, id: \.self) { shortcutIndex in
                        let shortcut = group.shortcuts[shortcutIndex]
                        GridRow {
                            HelpKeyboardShortcutKeys(keys: shortcut.keys)
                            Text(shortcut.action)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("help.keyboard-shortcuts")
    }
}
