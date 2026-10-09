import SwiftUI

/// Supplementary copy beside a heading or control, opened explicitly so it stays readable until dismissed.
struct HelpPopoverButton: View {
    let title: LocalizedStringKey
    let explanation: LocalizedStringKey
    @Environment(\.locale) private var locale
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingExplanation = false

    var body: some View {
        Button {
            isShowingExplanation.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(ThemePlainButtonStyle())
        .accessibilityLabel(Text(title))
        .accessibilityHint("Show explanation")
        .help("Show explanation")
        .popover(isPresented: $isShowingExplanation, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(explanation)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ThemePalette.ink)
            .frame(width: 280, alignment: .leading)
            .padding(16)
            .background(ThemePalette.contentSurface)
            // A native popover can start with its own presentation environment.
            .environment(\.locale, locale)
            .environment(\.appTheme, appTheme)
            .environment(\.colorScheme, colorScheme)
            .onExitCommand { isShowingExplanation = false }
        }
        .onDisappear { isShowingExplanation = false }
    }
}
