import SwiftUI

struct TerminalSplitDropHighlight: View {
    let store: ConversationStore
    let area: TerminalSplitDropArea

    @ObservedObject private var splitDropTargets = TabDragBetweenWindows.shared.splitDropTargets
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    private static let outlineWidth: CGFloat = 2

    var body: some View {
        let target = splitDropTargets.shownTarget.flatMap { $0.storeID == ObjectIdentifier(store) ? $0 : nil }
        ZStack(alignment: .topLeading) {
            if let target {
                let paneFrame = area.frame(of: target.place)
                ZStack {
                    RoundedRectangle(.card)
                        .fill(ThemePalette.pressedFill)
                    RoundedRectangle(.card)
                        .strokeBorder(ThemePalette.ink, lineWidth: Self.outlineWidth)
                    Text(target.title)
                        .font(ThemeFont.callout.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ThemePalette.raisedSurface, in: RoundedRectangle(.control))
                        .themeShadow(.floating)
                        .padding(.horizontal, 24)
                }
                .foregroundStyle(ThemePalette.ink)
                .frame(width: paneFrame.width, height: paneFrame.height)
                .offset(x: paneFrame.minX, y: paneFrame.minY)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(TabBarDragMetrics.slideAnimation, value: target)
        .environment(\.colorScheme, terminalPalette.colorScheme)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
