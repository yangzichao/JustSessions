import AppKit
import SwiftUI

/// The Permissions tab of Settings: what macOS allows JustSessions, read again whenever the tab shows or you come back
/// from System Settings, so one that is off stands out.
struct PermissionsSettingsView: View {
    var checker = SystemPermissionChecker()
    @State private var statuses: [AppPermission: AppPermissionStatus] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("macOS asks for these on behalf of JustSessions, also when a CLI in one of its terminals needs one. Checking here never shows a prompt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(AppPermission.onThisMac) { permission in
                ThemeDivider()
                PermissionRow(permission: permission, status: statuses[permission]) {
                    Task {
                        _ = await SessionNotificationCenter.requestAuthorization()
                        await checkAll()
                    }
                }
            }

            ThemeDivider()
            HStack {
                Spacer()
                Button("Check Again") { Task { await checkAll() } }
                    .buttonStyle(QuietBorderedButtonStyle())
            }
        }
        .task { await checkAll() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await checkAll() }
        }
    }

    private func checkAll() async {
        for permission in AppPermission.onThisMac {
            statuses[permission] = await checker.status(of: permission)
        }
    }
}
