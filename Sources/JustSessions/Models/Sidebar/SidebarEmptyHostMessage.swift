import Foundation

/// What the sidebar says under a host that lists no projects: that its refresh is running or failed, or that the
/// filters and search left nothing.
struct SidebarEmptyHostMessage: Equatable {
    let text: String
    /// The host's refresh failed, and `text` is its error.
    let isFailure: Bool

    init(host: SessionHost, refreshStatus: HostRefreshStatus?, isSearching: Bool, recencyFilter: SessionRecencyFilter) {
        switch refreshStatus {
        case .failed(let error)?:
            self.init(text: error, isFailure: true)
        case .refreshing?:
            self.init(text: host == .thisMac ? "Scanning sessions…" : "Copying sessions…")
        case .refreshed?, nil:
            if isSearching {
                self.init(text: "No matching projects or sessions")
            } else {
                self.init(text: recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions")
            }
        }
    }

    private init(text: String, isFailure: Bool = false) {
        self.text = text
        self.isFailure = isFailure
    }
}
