import SwiftUI

/// Help in Settings: the full shortcut list, grouped by where each shortcut applies.
struct HelpKeyboardShortcutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard shortcuts").font(.headline)
            // One grid for every group, so the actions line up down the whole list.
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Array(HelpKeyboardShortcutGroup.all.enumerated()), id: \.offset) { groupIndex, group in
                    Text(group.title)
                        .font(.subheadline.weight(.medium))
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
        .font(.callout)
        .accessibilityIdentifier("help.keyboard-shortcuts")
    }
}
