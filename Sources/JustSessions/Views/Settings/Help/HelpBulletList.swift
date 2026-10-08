import SwiftUI

/// Short parallel items in Help, such as what an SSH host needs, each after a bullet.
struct HelpBulletList: View {
    let items: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•")
                        .foregroundStyle(ThemePalette.secondaryText)
                        .accessibilityHidden(true)
                    Text(items[index])
                }
            }
        }
    }
}
