import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle).font(.headline).lineLimit(1)
                    Text("\(session.projectName) · \(session.provider.rawValue) · \(actionName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.hasExited {
                    Text(session.exitCode.map { "Exited (\($0))" } ?? "Ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
            EmbeddedTerminalView(session: session, isActive: isActive)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var actionName: String {
        switch session.action {
        case .new: "New"
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }
}
