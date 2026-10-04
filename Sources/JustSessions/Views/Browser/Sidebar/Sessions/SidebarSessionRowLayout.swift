import SwiftUI

/// What every session row under a project shares: the tool's icon, a one-line title, and trailing status, indented
/// under the project. Each row draws its own highlight, so a session row's can take in the ⋯ laid over its button.
struct SidebarSessionRowLayout<Title: View, Trailing: View>: View {
    let provider: ConversationProvider
    let isSelected: Bool
    let title: Title
    let trailing: Trailing

    init(
        provider: ConversationProvider,
        isSelected: Bool,
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.provider = provider
        self.isSelected = isSelected
        self.title = title()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            provider.iconImage(size: 10)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(provider.tintColor)
                .frame(width: 14)
            title
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            trailing
        }
        .padding(.leading, 28)
        .padding(.trailing, SidebarSessionRowMetrics.trailingPadding)
        .frame(height: 28)
        .contentShape(Rectangle())
    }
}

enum SidebarSessionRowMetrics {
    /// The room after a row's trailing status, which a session row's ⋯ lines up with.
    static let trailingPadding: CGFloat = 10
}
