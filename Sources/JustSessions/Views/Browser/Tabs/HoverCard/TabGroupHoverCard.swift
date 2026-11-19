import SwiftUI

struct TabGroupHoverCard: View {
    let projectName: String
    let location: ProjectLocation
    let tabs: [TerminalSession]

    static let maximumListedTabs = 8

    var body: some View {
        TabHoverCardSurface {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: projectName)
                    .font(ThemeFont.heading)
                    .foregroundStyle(ThemePalette.ink)
                    .lineLimit(2)
                Text(verbatim: folder)
                    .font(ThemeFont.detail.monospaced())
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tabs.prefix(Self.maximumListedTabs), id: \.id) { tab in
                        TabGroupHoverCardRow(session: tab)
                    }
                    if tabs.count > Self.maximumListedTabs {
                        Text("\(tabs.count - Self.maximumListedTabs) more tabs")
                            .font(ThemeFont.detail)
                            .foregroundStyle(ThemePalette.tertiaryText)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var folder: String {
        location.host == .thisMac ? (location.path as NSString).abbreviatingWithTildeInPath : location.copyablePath
    }
}

private struct TabGroupHoverCardRow: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        HStack(spacing: 6) {
            SessionStatusIndicator(status: session.runStatus)
            Text(verbatim: session.displayTitle)
                .lineLimit(1)
        }
        .font(ThemeFont.callout)
        .foregroundStyle(ThemePalette.secondaryText)
    }
}
