import AppKit
import SwiftUI

/// The app's icon as the Dock shows it. Clicking it opens the website.
struct AboutAppIconButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button { openURL(AppLinks.websiteURL) } label: {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
        }
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 4, cornerRadius: 22))
        .linkPointer()
        .help("Open the JustSessions website")
        .accessibilityLabel("JustSessions website")
        .accessibilityIdentifier("about.appIcon")
    }
}

private extension View {
    /// The pointing hand, so the icon reads as a link. SwiftUI sets pointers from macOS 15; on macOS 14 the hover
    /// surface alone shows that it can be clicked.
    @ViewBuilder func linkPointer() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.link)
        } else {
            self
        }
    }
}
