import SwiftUI

struct ThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(ThemePalette.hairline)
            .frame(height: 1)
    }
}
