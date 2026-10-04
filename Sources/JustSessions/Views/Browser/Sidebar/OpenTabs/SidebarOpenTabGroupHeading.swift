import SwiftUI

/// A project's name above its open tabs, in its tab bar group's color, with its SSH host and its tab count. It lines
/// up with the rows below instead of indenting them: its dot sits in their icon column and its name starts where their
/// titles do, so the rows keep the sidebar's full width.
struct SidebarOpenTabGroupHeading: View {
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int

    static let height: CGFloat = 24

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .frame(width: 14)
            HStack(spacing: 5) {
                Text(verbatim: projectName)
                    .foregroundStyle(color)
                    .layoutPriority(1)
                if let destination = location.host.sshDestination {
                    Image(systemName: location.host.symbolName)
                        .font(.system(size: 9, weight: .semibold))
                    Text(verbatim: destination)
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            Spacer(minLength: 6)
            Text(verbatim: "\(tabCount)")
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .help(Text(verbatim: location.copyablePath))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(projectName) tab group")
        .accessibilityValue(Text(verbatim: "\(tabCount)"))
        .accessibilityAddTraits(.isHeader)
    }
}
