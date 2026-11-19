import AppKit
import SwiftUI

struct SidebarPortForwardMenu: View {
    let entry: SSHPortForwards.Entry
    let onTryAgain: () -> Void
    let onStop: () -> Void

    var body: some View {
        Menu {
            switch entry.state {
            case .active:
                EmptyView()
            case .reconnecting:
                Text("Reconnecting…")
            case .connectionLost(let reason), .failed(let reason):
                Text(verbatim: reason)
                Button("Try again", systemImage: "arrow.clockwise", action: onTryAgain)
                Divider()
            }
            Button("Open in browser", systemImage: "safari") {
                if let url = entry.forward.browserURL { NSWorkspace.shared.open(url) }
            }
            .disabled(entry.state != .active)
            Button("Copy address", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.forward.address, forType: .string)
            }
            Divider()
            Button("Stop forwarding", systemImage: "stop.circle", action: onStop)
        } label: {
            Label {
                Text(verbatim: "\(entry.forward.address) → \(entry.forward.remotePort)")
            } icon: {
                Image(systemName: entry.state == .active ? "arrow.left.arrow.right" : "exclamationmark.triangle")
            }
        }
    }
}
