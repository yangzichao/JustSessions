import SwiftUI

struct TabHoverCardOverlay: View {
    let store: ConversationStore
    @ObservedObject var controller: TabHoverCardController

    var body: some View {
        GeometryReader { geometry in
            if let shownCard = controller.shownCard {
                let overlayOrigin = geometry.frame(in: .global).origin
                let anchorFrame = shownCard.anchorFrame.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)
                let leadingEdge = min(
                    max(anchorFrame.minX, TabHoverCardMetrics.windowMargin),
                    geometry.size.width - TabHoverCardMetrics.width - TabHoverCardMetrics.windowMargin
                )
                card(for: shownCard.target)
                    .offset(x: leadingEdge, y: anchorFrame.maxY + TabHoverCardMetrics.gapBelowTab)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: TabHoverCardMetrics.slideDuration), value: controller.shownCard?.target)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func card(for target: TabHoverCardTarget) -> some View {
        switch target {
        case .tab(let tabID):
            if let tab = store.terminalSessions.first(where: { $0.id == tabID }) {
                TerminalTabHoverCard(
                    session: tab,
                    projectDisplayName: store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
                    hostDisplayName: store.hasRemoteHosts ? tab.host.displayName : nil
                )
            }
        case .group(let projectKey):
            TabGroupHoverCard(
                projectName: store.projectDisplayName(forProjectPath: projectKey),
                location: ProjectLocation(key: projectKey),
                tabs: store.terminalSessions.filter { store.tabGroupKey(of: $0) == projectKey }
            )
        }
    }
}
