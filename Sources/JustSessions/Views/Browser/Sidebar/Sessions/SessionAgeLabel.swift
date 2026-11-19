import SwiftUI

struct SessionAgeLabel: View {
    let lastActivity: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(CompactRelativeTimeFormatter.string(for: lastActivity, relativeTo: context.date))
                .font(ThemeFont.detail.monospacedDigit())
                .foregroundStyle(ThemePalette.tertiaryText)
                .fixedSize()
        }
    }
}
