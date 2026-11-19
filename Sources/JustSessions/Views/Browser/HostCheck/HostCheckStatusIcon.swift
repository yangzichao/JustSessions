import SwiftUI

struct HostCheckStatusIcon: View {
    let status: HostCheckFinding.Status

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(color)
            .accessibilityLabel(HostCheckReport.label(for: status))
    }

    private var symbolName: String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .note: "info.circle"
        case .warning: "exclamationmark.triangle.fill"
        case .problem: "xmark.octagon.fill"
        }
    }

    private var color: AnyShapeStyle {
        switch status {
        case .passed: AnyShapeStyle(ThemePalette.live)
        case .note: AnyShapeStyle(ThemePalette.tertiaryText)
        case .warning: AnyShapeStyle(ThemePalette.warning)
        case .problem: AnyShapeStyle(ThemePalette.errorText)
        }
    }
}
