import AppKit
import SwiftUI

/// All / Recent switch with each option's session count. Neutral colors keep it quieter than
/// the accent-filled native segmented control, so the list's selected row stays the one accent in the sidebar.
struct SidebarRecencyPicker: View {
    @Binding var selection: SessionRecencyFilter
    let allSessionCount: Int
    let recentSessionCount: Int

    @Namespace private var selectedSegmentNamespace

    /// White in light mode and a translucent light gray in dark mode, like a native selected segment.
    private static let selectedSegmentFill = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.16)
            : NSColor.white
    })

    var body: some View {
        HStack(spacing: 2) {
            segment(.all, title: "All", count: allSessionCount)
            segment(.recent, title: "Recent", count: recentSessionCount)
                .help("Sessions active in the past seven days")
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func segment(_ filter: SessionRecencyFilter, title: String, count: Int) -> some View {
        let isSelected = selection == filter

        return Button {
            withAnimation(.snappy(duration: 0.2)) { selection = filter }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(count.formatted())
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Self.selectedSegmentFill)
                        .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                        .matchedGeometryEffect(id: "selectedSegment", in: selectedSegmentNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) \(count == 1 ? "session" : "sessions")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
