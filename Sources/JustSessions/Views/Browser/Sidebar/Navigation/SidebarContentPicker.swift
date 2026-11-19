import SwiftUI

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
        .background(ThemePalette.trackFill, in: RoundedRectangle(.control))
    }

    private func segment(_ mode: SidebarContentMode, title: LocalizedStringKey, count: Int? = nil) -> some View {
        let isSelected = selection == mode

        return Button {
            selection = mode
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(ThemeFont.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(ThemePalette.secondaryText))
                if let count {
                    Text(count.formatted())
                        .font(ThemeFont.detail.monospacedDigit())
                        .foregroundStyle(ThemePalette.secondaryText)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: InterfaceScale.points(22))
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(.small)
                        .fill(ThemePalette.raisedSurface)
                        .themeShadow(.raisedSegment)
                        .matchedGeometryEffect(id: "selectedSegment", in: selectedSegmentNamespace)
                }
            }
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
        .accessibilityLabel(Text(title))
        .accessibilityValue(count.map { String($0) } ?? "")
        .accessibilityIdentifier("sidebar.mode.\(mode.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onboardingTourStop(mode == .openTabs ? .openTabs : nil)
    }
}
