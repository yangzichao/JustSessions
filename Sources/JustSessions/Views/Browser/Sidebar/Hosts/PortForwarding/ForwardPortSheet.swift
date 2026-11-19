import SwiftUI

/// Forward a port…, from an SSH host's menu: forwards a port on this Mac to `localhost` on the host, picked from the
/// ports the host listens on or typed; see `SSHPortForwards`. The sheet stays open with ssh's reason when the forward
/// fails, and closes once it works, leaving the forward in the host's menu.
struct ForwardPortSheet: View {
    let host: String
    var forwards: SSHPortForwards = .shared

    private enum PortLookup {
        case lookingUp
        case listed([RemoteListeningPort])
        case noTool
        case failed
    }

    /// More rows than this scroll, so a busy host doesn't grow the sheet past the window.
    private static let rowsShownWithoutScrolling = 6

    @Environment(\.dismiss) private var dismiss
    @State private var form = ForwardPortForm()
    @State private var lookup = PortLookup.lookingUp
    @State private var isForwarding = false
    @State private var errorMessage: String?

    var body: some View {
        ThemeSheetLayout(
            title: Text("Forward a port"),
            intro: Text(
                "Reach a port on \(host) at localhost on this Mac. Only this Mac can use it, and it stops when JustSessions quits."),
            width: ThemeSheetMetrics.compactWidth
        ) {
            VStack(alignment: .leading, spacing: 14) {
                listeningPorts
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port on \(host)")
                            .font(ThemeFont.fieldLabel)
                            .lineLimit(1)
                        TextField("Port on the host", text: $form.remotePortText, prompt: Text("Such as 3000"))
                            .textFieldStyle(ThemedTextFieldStyle())
                            .onSubmit(forward)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port on this Mac")
                            .font(ThemeFont.fieldLabel)
                        TextField("Port on this Mac", text: $form.localPortText, prompt: localPortPrompt)
                            .textFieldStyle(ThemedTextFieldStyle())
                            .onSubmit(forward)
                    }
                }
                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        } footer: {
            if isForwarding {
                ProgressView().controlSize(.small)
                Text("Forwarding…")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Forward port", action: forward)
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!form.canForward || isForwarding)
        }
        .task { await lookUpListeningPorts() }
    }

    /// The host's port, which this Mac's port is unless another is typed.
    private var localPortPrompt: Text {
        form.remotePort.map { Text(verbatim: String($0)) } ?? Text("Same as on the host")
    }

    @ViewBuilder private var listeningPorts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Listening on \(host)")
                .font(ThemeFont.fieldLabel)
            switch lookup {
            case .lookingUp:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    lookupNote(Text("Looking up the ports \(host) listens on…"))
                }
            case .failed:
                lookupNote(Text("Couldn't ask \(host) which ports it listens on. Type the port instead."))
            case .noTool:
                lookupNote(Text("\(host) has no tool that lists its ports. Type the port instead."))
            case .listed(let ports) where ports.isEmpty:
                lookupNote(Text("Nothing on \(host) listens on a port that localhost reaches."))
            case .listed(let ports):
                Group {
                    if ports.count > Self.rowsShownWithoutScrolling {
                        ScrollView { rows(ports) }.frame(height: 190)
                    } else {
                        rows(ports)
                    }
                }
                .background(ThemePalette.raisedSurface, in: RoundedRectangle(.card))
                .overlay(RoundedRectangle(.card).stroke(ThemePalette.hairline, lineWidth: 1))
            }
        }
    }

    private func lookupNote(_ text: Text) -> some View {
        text
            .font(ThemeFont.callout)
            .foregroundStyle(ThemePalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rows(_ ports: [RemoteListeningPort]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ports) { port in
                row(for: port)
                if port != ports.last {
                    ThemeDivider()
                }
            }
        }
    }

    private func row(for port: RemoteListeningPort) -> some View {
        let isPicked = form.remotePort == port.port
        let forwardedFrom = forwards.entries(on: host).first { $0.forward.remotePort == port.port }?.forward
        let accessibilityName = port.programName.map { "\(port.port), \($0)" } ?? String(port.port)
        return Button {
            form.pick(port.port)
        } label: {
            rowLabel(for: port, forwardedFrom: forwardedFrom, isPicked: isPicked)
        }
        .buttonStyle(ThemePlainButtonStyle())
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(forwardedFrom.map { Text("Forwarded to \($0.address)") } ?? Text(verbatim: ""))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private func rowLabel(for port: RemoteListeningPort, forwardedFrom: SSHPortForward?, isPicked: Bool) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: String(port.port))
                .font(ThemeFont.body.weight(.medium).monospacedDigit())
            if let programName = port.programName {
                Text(verbatim: programName)
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let forwardedFrom {
                Text("Forwarded to \(forwardedFrom.address)")
                    .font(ThemeFont.detail)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            if isPicked {
                Image(systemName: "checkmark")
                    .font(ThemeFont.glyph(.control, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background {
            if isPicked { Rectangle().fill(ThemePalette.hoverFill) }
        }
    }

    private func lookUpListeningPorts() async {
        let host = host
        let listing = await Task.detached(priority: .userInitiated) { RemoteListeningPorts.lookUp(on: host) }.value
        switch listing {
        case nil: lookup = .failed
        case .noTool: lookup = .noTool
        case .listed(let ports): lookup = .listed(ports)
        }
    }

    private func forward() {
        guard let remotePort = form.remotePort, let localPort = form.localPort, !isForwarding else { return }
        isForwarding = true
        errorMessage = nil
        Task {
            let failure = await forwards.forward(remotePort: remotePort, localPort: localPort, on: host)
            isForwarding = false
            if let failure {
                errorMessage = failure.message
            } else {
                dismiss()
            }
        }
    }
}
