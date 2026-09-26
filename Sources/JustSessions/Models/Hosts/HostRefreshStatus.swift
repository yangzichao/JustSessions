import Foundation

/// Where the last refresh of a host's sessions stands: a scan of the session folders on this Mac, or a copy of an
/// SSH host's session files into the local mirror.
enum HostRefreshStatus: Equatable {
    case refreshing
    case refreshed(Date)
    case failed(String)
}
