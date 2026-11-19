import SwiftUI

struct AddRemoteHostFieldNote: View {
    let input: RemoteHostInput
    let isListed: Bool
    let sameMachineCheck: SSHHostSameMachineCheck?
    let connectionFailure: String?

    var body: some View {
        if let connectionFailure {
            warning(Text(verbatim: connectionFailure))
        } else {
            switch input {
            case .notADestination:
                warning(
                    Text(
                        "Enter only the host, such as `devbox` or `me@devbox`. Options such as a key or a jump host go in `~/.ssh/config`.")
                )
            case .needsPortInConfig(let user, let hostName, let port):
                portInConfig(user: user, hostName: hostName, port: port)
            case .destination(let host) where isListed:
                warning(Text("\(host) is already added."))
            case .destination:
                if let listedHost = sameMachineCheck?.listedHostWithSameIdentity, let identity = sameMachineCheck?.identity {
                    warning(Text("Already added as \(listedHost), which also connects to \(identity.userAtHostName)."))
                } else {
                    requirements
                }
            case .empty:
                requirements
            }
        }
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let identity = sameMachineCheck?.identity {
                Group {
                    if let port = identity.nonStandardPort {
                        Text("Connects to \(identity.userAtHostName), port \(port).")
                    } else {
                        Text("Connects to \(identity.userAtHostName).")
                    }
                }
                .textSelection(.enabled)
            }
            Text("Works with SSH keys, or with a password or code.")
        }
        .font(ThemeFont.caption)
        .foregroundStyle(ThemePalette.secondaryText)
    }

    private func portInConfig(user: String?, hostName: String, port: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            warning(Text("A port goes in `~/.ssh/config`. Add these lines there, then enter \(hostName)."))
            Text(verbatim: RemoteHostInput.configLines(user: user, hostName: hostName, port: port))
                .font(ThemeFont.callout.monospaced())
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemePalette.trackFill, in: RoundedRectangle(.small))
        }
    }

    private func warning(_ text: Text) -> some View {
        text
            .font(ThemeFont.callout)
            .foregroundStyle(ThemePalette.warningText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
