import SwiftUI

/// How long ago a session was last active, such as "5m" or "Sep 3"; refreshes every minute.
struct SessionAgeLabel: View {
    let lastActivity: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(CompactRelativeTimeFormatter.string(for: lastActivity, relativeTo: context.date))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
    }
}
