import SwiftUI

struct TranscriptBookmarkNoticeCard: View {
    let state: TranscriptBookmarkState
    let onRemoveBookmark: (MessageBookmark) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        if let notice = state.notice {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: notice.text(language: AppInterfaceLanguage(identifier: locale.identifier)))
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if case .missing(let bookmark) = notice {
                    Button("Remove bookmark") { onRemoveBookmark(bookmark) }
                        .buttonStyle(QuietBorderedButtonStyle())
                        .controlSize(.small)
                        .accessibilityIdentifier("preview.bookmark-notice.remove")
                }
                Button(action: state.dismissNotice) {
                    Image(systemName: "xmark")
                        .font(ThemeFont.glyph(.control, weight: .semibold))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: InterfaceScale.points(22), height: InterfaceScale.points(22))
                        .contentShape(Circle())
                }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
                .help("Close")
                .accessibilityLabel("Close")
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: InterfaceScale.points(360), alignment: .leading)
            .background {
                RoundedRectangle(.card)
                    .fill(ThemePalette.raisedSurface)
                    .themeShadow(.floating)
            }
            .overlay { RoundedRectangle(.card).strokeBorder(ThemePalette.hairline) }
            .padding(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("preview.bookmark-notice")
        }
    }
}
