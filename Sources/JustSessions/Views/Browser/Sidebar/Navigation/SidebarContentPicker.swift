import SwiftUI

/// Projects browse the library; Open tabs switches among terminals already open in this window.
struct SidebarContentPicker: View {
    @Binding var selection: SidebarContentMode
    let openTabCount: Int

    @Namespace private var selectedSegmentNamespace

    var body: some View {
        HStack(spacing: 2) {
            segment(.projects, title: "Projects")
            segment(.openTabs, title: "Open tabs", count: openTabCount)
        }
        .padding(2)
        .background(ThemePalette.trackFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func segment(_ mode: SidebarContentMode, title: LocalizedStringKey, count: Int? = nil) -> some View {
        let isSelected = selection == mode

        return Button {
            selection = mode
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(ThemePalette.secondaryText))
                if let count {
                    Text(count.formatted())
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ThemePalette.secondaryText)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(ThemePalette.raisedSurface)
                        .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                        .matchedGeometryEffect(id: "selectedSegment", in: selectedSegmentNamespace)
                }
            }
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: 5))
        .accessibilityLabel(Text(title))
        .accessibilityValue(count.map { String($0) } ?? "")
        .accessibilityIdentifier("sidebar.mode.\(mode.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onboardingTourStop(mode == .openTabs ? .openTabs : nil)
    }
}
