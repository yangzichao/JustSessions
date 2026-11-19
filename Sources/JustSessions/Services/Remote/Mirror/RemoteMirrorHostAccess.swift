import Foundation

struct RemoteMirrorHostAccess: Sendable {
    var connectionSharing: @Sendable (_ host: String) -> SSHConnectionSharing?
    var commandRunner: @Sendable (_ connectionSharingOptions: [String]) -> RemoteHostCommandRunner
    var rsyncRemoteShell: @Sendable (_ connectionSharingOptions: [String]) -> String

    static let ssh = RemoteMirrorHostAccess(
        connectionSharing: { SSHConnectionSharing.startRefresh(to: $0) },
        commandRunner: { RemoteHostCommandRunner(connectionSharingOptions: $0, cancelsWithTask: true) },
        rsyncRemoteShell: { RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: $0) }
    )
}
