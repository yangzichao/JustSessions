import SwiftUI

extension View {
    /// Reports where the view sits in its window to the window's hover card, as the place the card for `target`
    /// hangs from.
    func tabHoverCardAnchor(_ target: TabHoverCardTarget) -> some View {
        modifier(TabHoverCardAnchorReporting(target: target))
    }
}

private struct TabHoverCardAnchorReporting: ViewModifier {
    let target: TabHoverCardTarget
    @Environment(\.tabHoverCards) private var hoverCards

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                hoverCards?.report(frame, of: target)
            }
            .onDisappear { hoverCards?.report(nil, of: target) }
    }
}
