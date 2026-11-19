import SwiftUI

struct SidebarHostCheckProblemWarning: View {
    let host: SessionHost
    let problemMessage: String
    let onShowHostCheck: () -> Void

    var body: some View {
        Button(action: onShowHostCheck) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemePalette.warning)
                .frame(width: InterfaceScale.points(14), height: InterfaceScale.points(20))
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePressButtonStyle())
        .help(AppLocalization.string("\(problemMessage) Click to see what the check found."))
        .accessibilityLabel("\(host.displayName) has a problem: \(problemMessage)")
        .accessibilityHint("Shows what the check found")
    }
}
