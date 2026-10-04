import SwiftUI

/// The small toolbar in a split pane's bottom-trailing corner, as Chrome's `MultiContentsViewMiniToolbar`: in the
/// split area's color, sitting in a notch of the pane's outline. The other pane's toolbar names its tab, with the tab's
/// status and title; the selected tab's pane shows only the ×, which closes that tab through the usual close request. A
/// click on the toolbar outside its × selects the pane's tab, as a click in the pane does.
struct WorkspaceSplitMiniToolbar: View {
    @ObservedObject var session: TerminalSession
    /// Shows the tab's status and title, as on the pane whose tab is not selected.
    let showsTabDetails: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    /// Chrome's `kMiniToolbarDomainMaxWidth`.
    private static let titleMaximumWidth: CGFloat = 140

    var body: some View {
        let outlineWidth = WorkspaceSplitPaneMetrics.outlineWidth
        let cornerRadius = WorkspaceSplitPaneMetrics.outlineCornerRadius
        let contentPadding = WorkspaceSplitPaneMetrics.miniToolbarContentPadding
        let buttonSize = WorkspaceSplitPaneMetrics.miniToolbarButtonSize
        HStack(spacing: 6) {
            if showsTabDetails {
                TerminalStatusIndicator(session: session)
                MaximumWidth(Self.titleMaximumWidth) {
                    Text(session.displayTitle)
                        .lineLimit(1)
                }
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(ThemePlainButtonStyle(cornerRadius: buttonSize / 2))
            .help("Close this view")
            .accessibilityLabel("Close this view")
        }
        // As tall as the ×, so the toolbar is `miniToolbarHeight` tall in either pane, which the terminal ends above.
        .frame(height: buttonSize)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ThemePalette.ink)
        // Chrome's margins: clear of the notch's curves at the top and leading side, which leaves the title more room,
        // and on the outline's edge at the bottom and trailing side.
        .padding(.top, cornerRadius + contentPadding)
        .padding(.leading, showsTabDetails ? cornerRadius * 2 : cornerRadius + contentPadding)
        .padding([.bottom, .trailing], outlineWidth)
        .background(WorkspaceSplitMiniToolbarShape().fill(terminalPalette.backgroundColor))
        .contentShape(WorkspaceSplitMiniToolbarShape())
        .onTapGesture(perform: onSelect)
        // It sits on the terminal's background, which can be dark in a light window or the reverse.
        .environment(\.colorScheme, terminalPalette.colorScheme)
        .accessibilityElement(children: .contain)
    }
}

/// Lays its content out no wider than `maximumWidth`, and only as wide as the content needs, so a short title keeps
/// the toolbar small and a long one is cut short. A `frame(maxWidth:)` would always take the full width offered.
private struct MaximumWidth: Layout {
    let maximumWidth: CGFloat

    init(_ maximumWidth: CGFloat) {
        self.maximumWidth = maximumWidth
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(limited(proposal)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }

    private func limited(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: min(proposal.width ?? maximumWidth, maximumWidth), height: proposal.height)
    }
}
