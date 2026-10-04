import SwiftUI

/// One permission: its name and status, what it is for, and the button that changes it.
struct PermissionRow: View {
    let permission: AppPermission
    /// Nil until the first check finishes.
    let status: AppPermissionStatus?
    /// Shows macOS's notification prompt, which only notifications offer before macOS has asked.
    let onAskForNotifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(permission.title)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 12)
                if let status {
                    AppPermissionStatusLabel(status: status, isOptional: permission.isOptional)
                }
            }
            Text(permission.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if permission == .notifications, status == .notAskedYet {
                    Button("Ask Now", action: onAskForNotifications)
                }
                Button("Open System Settings") { permission.openSystemSettings() }
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .contain)
    }
}
