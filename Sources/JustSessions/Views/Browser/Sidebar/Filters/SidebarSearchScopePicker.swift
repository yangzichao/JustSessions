import SwiftUI

struct SidebarSearchScopePicker: View {
    @Binding var selection: SidebarSearchScope

    var body: some View {
        HStack(spacing: 4) {
            scopeButton(.everything, title: "All")
            scopeButton(.namesOnly, title: "Names only")
        }
        .accessibilityRepresentation {
            Picker("Search in", selection: $selection) {
                Text("All").tag(SidebarSearchScope.everything)
                Text("Names only").tag(SidebarSearchScope.namesOnly)
            }
            .pickerStyle(.segmented)
        }
    }

    private func scopeButton(_ scope: SidebarSearchScope, title: LocalizedStringKey) -> some View {
        let isSelected = selection == scope

        return Button {
            selection = scope
        } label: {
            Text(title)
                .font(ThemeFont.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(ThemePalette.secondaryText))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: InterfaceScale.points(20))
                .background {
                    if isSelected {
                        RoundedRectangle(.small).fill(ThemePalette.trackFill)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
    }
}
