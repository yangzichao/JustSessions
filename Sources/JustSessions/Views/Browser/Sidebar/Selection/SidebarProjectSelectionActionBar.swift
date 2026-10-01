import SwiftUI

struct SidebarProjectSelectionActionBar: View {
    let selectedCount: Int
    let onClear: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(CountedNoun.phrase(count: selectedCount, singular: "project")) selected")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("Clear", action: onClear)
                    .buttonStyle(.borderless)
            }
            Button(action: onRemove) {
                Label("Remove from sidebar", systemImage: "sidebar.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Remove selected projects from the sidebar; keep sessions and open terminals")
            .accessibilityLabel("Remove selected projects from sidebar")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(ThemePalette.hoverFill)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedCount) projects selected")
    }
}
