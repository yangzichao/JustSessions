import SwiftUI

struct NotificationBellRow: View {
    let entry: NotificationBellEntry
    let onShow: () -> Void

    static var height: CGFloat { InterfaceScale.points(42) }

    var body: some View {
        Button(action: onShow) {
            HStack(spacing: 8) {
                entry.provider.iconImage(size: 10)
                    .foregroundStyle(entry.provider.tintColor)
                    .font(ThemeFont.glyph(.control, weight: .medium))
                    .frame(width: InterfaceScale.points(14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.sessionTitle)
                        .font(ThemeFont.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    details
                }
                Spacer(minLength: 6)
                SessionStatusIndicator(status: status)
            }
            .padding(.horizontal, 8)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: false)
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help(Text("Show \(entry.sessionTitle)"))
        .accessibilityLabel(Text(verbatim: "\(entry.sessionTitle), ") + Text(reason) + Text(verbatim: ", \(entry.projectName)"))
    }

    private var details: some View {
        HStack(spacing: 4) {
            Text(reason)
                .fixedSize()
            Text(verbatim: "·")
            Text(verbatim: entry.projectName)
                .lineLimit(1)
                .truncationMode(.tail)
            if let waitingSince = entry.waitingSince {
                Text(verbatim: "·")
                SessionAgeLabel(lastActivity: waitingSince)
            }
        }
        .font(ThemeFont.detail)
        .foregroundStyle(ThemePalette.secondaryText)
    }

    private var reason: LocalizedStringKey {
        switch entry.reason {
        case .needsInput: "Needs your input"
        case .finishedTurn: "Finished its turn"
        }
    }

    private var status: SessionRunStatus {
        switch entry.reason {
        case .needsInput(let reason): .running(.needsInput(reason: reason))
        case .finishedTurn: .finishedUnseen
        }
    }
}
