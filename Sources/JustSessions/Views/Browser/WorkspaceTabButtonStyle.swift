import SwiftUI

/// Chip look shared by the Preview tab and terminal tabs.
/// The selected tab is a solid accent chip so it stands out from the muted, unselected ones.
struct WorkspaceTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
