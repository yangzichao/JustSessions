import SwiftUI

struct TranscriptBookmarkLabel: View {
    @Environment(\.transcriptSearchEntryIndex) private var entryID
    @Environment(\.transcriptBookmarkLetters) private var letters

    var body: some View {
        if let label = letters.bookmark(forEntryID: entryID)?.label {
            HStack(spacing: 4) {
                Image(systemName: "bookmark.fill")
                    .imageScale(.small)
                Text(verbatim: label)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(ThemeFont.caption.weight(.semibold))
            .foregroundStyle(ThemePalette.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(ThemePalette.trackFill, in: RoundedRectangle(.small))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
