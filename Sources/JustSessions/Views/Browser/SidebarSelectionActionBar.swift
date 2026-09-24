import SwiftUI

/// Shown at the bottom of the sidebar while several sessions are selected.
struct SidebarSelectionActionBar: View {
    let selectedCount: Int
    let isDeleteDisabled: Bool
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(selectedCount) selected")
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 4)
            Button("Clear", action: onClear)
                .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Label("Delete…", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isDeleteDisabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.08))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedCount) sessions selected")
    }
}
