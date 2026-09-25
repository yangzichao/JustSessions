import SwiftUI

/// A one-point hairline in the theme's line color, in place of the system `Divider`'s cooler gray.
struct ThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(ThemePalette.hairline)
            .frame(height: 1)
    }
}
