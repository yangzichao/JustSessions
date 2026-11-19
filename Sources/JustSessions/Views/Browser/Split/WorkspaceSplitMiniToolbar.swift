import SwiftUI

struct WorkspaceSplitMiniToolbar: View {
    @ObservedObject var session: TerminalSession
    let showsTabDetails: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette

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
                    .font(ThemeFont.glyph(.control, weight: .bold))
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
            .help("Close this view")
            .accessibilityLabel("Close this view")
        }
        .frame(height: buttonSize)
        .font(ThemeFont.callout.weight(.medium))
        .foregroundStyle(ThemePalette.ink)
        .padding(.top, cornerRadius + contentPadding)
        .padding(.leading, showsTabDetails ? cornerRadius * 2 : cornerRadius + contentPadding)
        .padding([.bottom, .trailing], outlineWidth)
        .background(WorkspaceSplitMiniToolbarShape().fill(terminalPalette.backgroundColor))
        .contentShape(WorkspaceSplitMiniToolbarShape())
        .onTapGesture(perform: onSelect)
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
