import SwiftUI

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
                    .background(ThemePalette.raisedSurface, in: RoundedRectangle(.small))
                    .overlay {
                        RoundedRectangle(.small).stroke(ThemePalette.hairline)
                    }
            }
        }
        .fixedSize()
    }
}
