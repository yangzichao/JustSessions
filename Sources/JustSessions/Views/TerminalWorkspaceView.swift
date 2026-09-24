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
                Button {
                    session.copySelection()
                } label: {
                    Label("Copy selection", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(!session.hasSelection)
                .help("Drag to select terminal text, then copy it (⌘C)")

                Toggle("CLI mouse", isOn: Binding(
                    get: { session.allowsCLIMouseInput },
                    set: { session.setCLIMouseInputEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Let the CLI use mouse clicks. Hold Shift while dragging to select text.")
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
