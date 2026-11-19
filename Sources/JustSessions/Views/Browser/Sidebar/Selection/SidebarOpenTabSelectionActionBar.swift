import SwiftUI

struct SidebarOpenTabSelectionActionBar: View {
    let selectedCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(selectedCount) tabs selected")
                .font(ThemeFont.callout.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(role: .destructive, action: onClose) {
                Label("Close \(selectedCount) tabs…", systemImage: "xmark")
            }
            .buttonStyle(QuietBorderedButtonStyle())
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(ThemePalette.hoverFill)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedCount) tabs selected")
    }
}
