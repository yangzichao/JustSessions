import SwiftUI

/// A tab group's hover card, from its label, as Chrome's group hover card: the project, its folder, and each of the
/// group's tabs with what its CLI is doing, which shows what a collapsed group holds.
struct TabGroupHoverCard: View {
    let projectName: String
    let location: ProjectLocation
    let tabs: [TerminalSession]

    /// Past this many, the card counts the rest instead of listing them.
    static let maximumListedTabs = 8

    var body: some View {
        TabHoverCardSurface {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemePalette.ink)
                    .lineLimit(2)
                Text(verbatim: folder)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tabs.prefix(Self.maximumListedTabs), id: \.id) { tab in
                        TabGroupHoverCardRow(session: tab)
                    }
                    if tabs.count > Self.maximumListedTabs {
                        Text("\(tabs.count - Self.maximumListedTabs) more tabs")
                            .font(.system(size: 11))
                            .foregroundStyle(ThemePalette.tertiaryText)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    /// This Mac's folders start from ~, as in the Finder; an SSH host's keep the host in front.
    private var folder: String {
        location.host == .thisMac ? (location.path as NSString).abbreviatingWithTildeInPath : location.copyablePath
    }
}

/// One of the group's tabs on its hover card, kept current while the card shows.
private struct TabGroupHoverCardRow: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        HStack(spacing: 6) {
            SessionStatusIndicator(status: session.runStatus)
            Text(verbatim: session.displayTitle)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(ThemePalette.secondaryText)
    }
}
