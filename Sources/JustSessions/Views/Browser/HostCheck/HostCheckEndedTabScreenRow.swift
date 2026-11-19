import SwiftUI

struct HostCheckEndedTabScreenRow: View {
    let screenText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("What the tab showed when it ended:")
                .font(ThemeFont.detail)
                .foregroundStyle(ThemePalette.tertiaryText)
            HostCheckMonospacedText(text: screenText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
