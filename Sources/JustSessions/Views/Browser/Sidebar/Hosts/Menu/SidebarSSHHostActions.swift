import SwiftUI

struct SidebarSSHHostActions {
    let usesTmuxPrefix: Binding<Bool>
    let shellStartupCheck: RemoteShellStartupCheckResult?
    let onCheckHost: () -> Void
    let hostCheckProblem: String?
    let onShowHostCheck: () -> Void
    let login: SidebarSSHHostLogin
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onConnectDisconnectedHost: () -> Void
    let signIn: RemoteSignIns.State?
    let onSignIn: () -> Void
    let onEditSignInCommand: () -> Void
    let portForwards: [SSHPortForwards.Entry]
    let onForwardPort: () -> Void
    let onTryPortForwardsAgain: () -> Void
    let onStopPortForward: (SSHPortForward) -> Void
    let onRemove: () -> Void
}
