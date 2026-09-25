import SwiftUI

struct TerminalSidebarRow: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    let isSelected: Bool
    let onSelect: () -> Void

    private var actionName: String {
        switch session.action {
        case .new: "New"
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: session.provider.symbolName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(session.provider.tintColor)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                    Text("\(projectDisplayName) · \(actionName)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                TerminalStatusIndicator(session: session)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .help(session.hasExited ? "Terminal ended; open its tab to review" : "Switch to open terminal")
        .accessibilityLabel("\(session.hasExited ? "Ended" : "Running") terminal: \(session.displayTitle)")
    }
}

struct TerminalStatusIndicator: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        Image(systemName: session.hasExited ? "circle" : "circle.fill")
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(session.hasExited ? Color.secondary : Color.green)
            .accessibilityLabel(session.hasExited ? "Ended" : "Running")
    }
}
