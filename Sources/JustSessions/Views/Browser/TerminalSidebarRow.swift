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
            HStack(spacing: 9) {
                TerminalStatusIndicator(session: session)
                    .frame(width: 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayTitle)
                        .lineLimit(1)
                    Text("\(projectDisplayName) · \(actionName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
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
