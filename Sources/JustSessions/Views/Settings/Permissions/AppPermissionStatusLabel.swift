import SwiftUI

/// A permission's status as a colored symbol and a word. One that is off stands out only when something depends on it.
struct AppPermissionStatusLabel: View {
    let status: AppPermissionStatus
    let isOptional: Bool

    var body: some View {
        let label = Label {
            Text(title)
        } icon: {
            Image(systemName: symbolName).foregroundStyle(symbolColor)
        }
        .font(.callout)
        if let help {
            label.help(help)
        } else {
            label
        }
    }

    private var title: LocalizedStringKey {
        switch status {
        case .allowed: "Allowed"
        case .notAllowed: "Not allowed"
        case .notAskedYet: "Not asked yet"
        case .unknown: "Can't check"
        }
    }

    private var symbolName: String {
        switch status {
        case .allowed: "checkmark.circle.fill"
        case .notAllowed: isOptional ? "minus.circle" : "exclamationmark.triangle.fill"
        case .notAskedYet: "circle.dashed"
        case .unknown: "questionmark.circle"
        }
    }

    private var symbolColor: AnyShapeStyle {
        switch status {
        case .allowed: AnyShapeStyle(ThemePalette.live)
        case .notAllowed where !isOptional: AnyShapeStyle(ThemePalette.warning)
        case .notAllowed, .notAskedYet, .unknown: AnyShapeStyle(ThemePalette.secondaryText)
        }
    }

    private var help: LocalizedStringKey? {
        switch status {
        case .allowed, .notAllowed: nil
        case .notAskedYet: "macOS asks the first time JustSessions needs it."
        case .unknown: "macOS doesn't let apps check this. Look for JustSessions in System Settings."
        }
    }
}
