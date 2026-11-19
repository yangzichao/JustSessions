import SwiftUI

struct SidebarSessionRowLayout<Title: View, Detail: View, Trailing: View>: View {
    let provider: ConversationProvider
    let isSelected: Bool
    let indentLevel: Int
    let title: Title
    let detail: Detail?
    let trailing: Trailing

    init(
        provider: ConversationProvider,
        isSelected: Bool,
        indentLevel: Int = 0,
        @ViewBuilder title: () -> Title,
        detail: Detail?,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.provider = provider
        self.isSelected = isSelected
        self.indentLevel = indentLevel
        self.title = title()
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                provider.iconImage(size: 10)
                    .font(ThemeFont.glyph(.control, weight: .medium))
                    .foregroundStyle(provider.tintColor)
                    .frame(width: SidebarSessionRowMetrics.iconWidth)
                title
                    .font(ThemeFont.callout.weight(isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                trailing
            }
            .frame(height: InterfaceScale.points(28))
            if let detail {
                detail
                    .padding(.leading, SidebarSessionRowMetrics.iconWidth + 8)
                    .padding(.top, -3)
                    .padding(.bottom, 6)
            }
        }
        .padding(.leading, SidebarSessionRowMetrics.leadingPadding(indentLevel: indentLevel))
        .padding(.trailing, SidebarSessionRowMetrics.trailingPadding)
        .contentShape(Rectangle())
    }
}

extension SidebarSessionRowLayout where Detail == EmptyView {
    init(
        provider: ConversationProvider,
        isSelected: Bool,
        indentLevel: Int = 0,
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(provider: provider, isSelected: isSelected, indentLevel: indentLevel, title: title, detail: nil, trailing: trailing)
    }
}

enum SidebarSessionRowMetrics {
    static let trailingPadding: CGFloat = 10
    static let indentStep: CGFloat = 14

    static func leadingPadding(indentLevel: Int) -> CGFloat {
        28 + CGFloat(indentLevel) * indentStep
    }

    static let iconWidth: CGFloat = 14
}
