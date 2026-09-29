import SwiftUI

/// What every session row under a project shares: the tool's icon, a one-line title, and trailing status,
/// indented under the project and washed in the tool's hue when selected.
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
            Image(systemName: provider.symbolName)
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
        .padding(.trailing, 10)
        .frame(height: 28)
        .contentShape(Rectangle())
        .sidebarRowHighlight(isSelected: isSelected, selectionTint: provider.tintColor)
    }
}
