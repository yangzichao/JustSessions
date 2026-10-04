import SwiftUI

/// A shortcut's keys, each as a key cap. A slash separates alternatives.
struct HelpKeyboardShortcutKeys: View {
    let keys: [Text]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys.indices, id: \.self) { index in
                if index > 0 {
                    Text(verbatim: "/")
                        .foregroundStyle(ThemePalette.secondaryText)
                        .accessibilityHidden(true)
                }
                keys[index]
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4).stroke(ThemePalette.hairline)
                    }
            }
        }
        .fixedSize()
    }
}
