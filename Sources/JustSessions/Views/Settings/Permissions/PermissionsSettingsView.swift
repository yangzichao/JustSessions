import AppKit
import SwiftUI

struct PermissionsSettingsView: View {
    var checker = SystemPermissionChecker()
    @State private var statuses: [AppPermission: AppPermissionStatus] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Permissions")
                    .font(ThemeFont.heading)
                HelpPopoverButton(
                    title: "Permissions",
                    explanation:
                        "macOS asks for these on behalf of JustSessions, also when a CLI in one of its terminals needs one. Checking here never shows a prompt."
                )
                .accessibilityIdentifier("settings.help.permissions")
            }

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
