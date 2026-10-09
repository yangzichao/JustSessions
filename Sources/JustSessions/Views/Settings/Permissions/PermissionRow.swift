import SwiftUI

/// One permission: its name, on-demand explanation, status, and the button that changes it.
struct PermissionRow: View {
    let permission: AppPermission
    /// Nil until the first check finishes.
    let status: AppPermissionStatus?
    /// Shows macOS's notification prompt, which only notifications offer before macOS has asked.
    let onAskForNotifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(permission.title)
                    .font(.subheadline.weight(.medium))
                if permission.isOptional {
                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                HelpPopoverButton(title: permission.title, explanation: permission.explanation)
                    .accessibilityIdentifier("settings.help.permission.\(permission.id)")
                Spacer(minLength: 12)
                if let status {
                    AppPermissionStatusLabel(status: status, isOptional: permission.isOptional)
                }
            }
            HStack(spacing: 8) {
                if permission == .notifications, status == .notAskedYet {
                    Button("Ask Now", action: onAskForNotifications)
                }
                Button("Open System Settings") { permission.openSystemSettings() }
            }
            .buttonStyle(QuietBorderedButtonStyle())
            .controlSize(.small)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .contain)
    }
}
