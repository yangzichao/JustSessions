import SwiftUI

/// What every session row under a project shares: the tool's icon, a one-line title, and trailing status, indented
/// under the project, with an optional detail under the title, such as a search's match in the session's messages.
/// Each row draws its own highlight, so a session row's can take in the ⋯ laid over its button.
struct SidebarSessionRowLayout<Title: View, Detail: View, Trailing: View>: View {
    let provider: ConversationProvider
    let isSelected: Bool
    let title: Title
    let detail: Detail?
    let trailing: Trailing

    init(
        provider: ConversationProvider,
        isSelected: Bool,
        @ViewBuilder title: () -> Title,
        detail: Detail?,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.provider = provider
        self.isSelected = isSelected
        self.title = title()
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                provider.iconImage(size: 10)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(provider.tintColor)
                    .frame(width: SidebarSessionRowMetrics.iconWidth)
                title
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                trailing
            }
            .frame(height: 28)
            if let detail {
                // Lined up with the title, under it.
                detail
                    .padding(.leading, SidebarSessionRowMetrics.iconWidth + 8)
                    .padding(.top, -3)
                    .padding(.bottom, 6)
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, SidebarSessionRowMetrics.trailingPadding)
        .contentShape(Rectangle())
    }
}

extension SidebarSessionRowLayout where Detail == EmptyView {
    init(
        provider: ConversationProvider,
        isSelected: Bool,
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(provider: provider, isSelected: isSelected, title: title, detail: nil, trailing: trailing)
    }
}

enum SidebarSessionRowMetrics {
    /// The room after a row's trailing status, which a session row's ⋯ lines up with.
    static let trailingPadding: CGFloat = 10
    static let iconWidth: CGFloat = 14
}
