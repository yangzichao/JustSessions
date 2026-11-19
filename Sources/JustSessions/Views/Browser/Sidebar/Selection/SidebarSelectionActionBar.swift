import SwiftUI

struct SidebarSelectionActionBar: View {
    let selectedCount: Int
    let endableCount: Int
    let onEnd: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(selectedCount) selected")
                    .font(ThemeFont.callout.weight(.medium))
                Spacer(minLength: 4)
                Button(role: .destructive, action: onDelete) {
                    Label("Delete…", systemImage: "trash")
                }
                .buttonStyle(QuietBorderedButtonStyle())
                .controlSize(.small)
            }
            if endableCount > 0 {
                Button(role: .destructive, action: onEnd) {
                    Label("End \(endableCount) sessions", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(QuietBorderedButtonStyle())
                .controlSize(.small)
                .help("Stop the running CLIs of the selected sessions; they can be resumed")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(ThemePalette.hoverFill)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedCount) sessions selected")
    }
}
