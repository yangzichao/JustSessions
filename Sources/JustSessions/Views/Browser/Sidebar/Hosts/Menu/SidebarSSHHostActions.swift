import SwiftUI

/// What an SSH host's heading offers that this Mac's does not; see `SidebarSSHHostMenuItems`.
struct SidebarSSHHostActions {
    /// Whether the host's tmux sessions use its own prefix keys; see `RemoteTmuxPrefixOptions`.
    let usesTmuxPrefix: Binding<Bool>
    let onRemove: () -> Void
}
