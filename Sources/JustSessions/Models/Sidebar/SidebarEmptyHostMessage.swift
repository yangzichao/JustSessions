import Foundation

/// What the sidebar says under a host that lists no projects: that its refresh is running or failed, that you
/// disconnected from it before it was copied, or that the filters and search left nothing.
struct SidebarEmptyHostMessage: Equatable {
    let text: String
    let localizedText: LocalizedStringResource?
    /// The host's refresh failed, and `text` is its error.
    let isFailure: Bool

    init(
        host: SessionHost,
        refreshStatus: HostRefreshStatus?,
        copyStep: RemoteSessionCopyStep?,
        isSearching: Bool,
        recencyFilter: SessionRecencyFilter,
        statusFilter: SessionStatusFilter,
        isDisconnected: Bool = false
    ) {
        // Nothing is known of a disconnected host beyond its last copy, which lists nothing here.
        if isDisconnected, refreshStatus != .refreshing {
            self.init(text: isSearching ? "No matching projects or sessions" : "Disconnected. Connect to copy its sessions.")
            return
        }
        switch refreshStatus {
        case .failed(let error)?:
            self.init(failure: error)
        case .refreshing?:
            if host == .thisMac {
                self.init(text: "Scanning sessions…")
            } else if let copyStep {
                self.init(text: "Copying \(copyStep.provider.rawValue) sessions (\(copyStep.number) of \(copyStep.count))…")
            } else {
                self.init(text: "Copying sessions…")
            }
        case .refreshed?, nil:
            if isSearching {
                self.init(text: "No matching projects or sessions")
            } else if statusFilter == .running {
                // An SSH host's running sessions are known as of its last refresh, so say so rather than claim
                // nothing runs there now.
                self.init(
                    text: host == .thisMac
                        ? "No session is running"
                        : "No session was running at the last refresh")
            } else if statusFilter == .waitingForYou {
                // Only Claude Code, Codex, Antigravity, Pi, and OpenCode on this Mac tell what they are doing, so say
                // so rather than suggest nothing else waits.
                self.init(
                    text: host == .thisMac
                        ? "No Claude Code, Codex, Antigravity, Pi, or OpenCode session is waiting for you"
                        : "SSH hosts don't tell when a session waits for you")
            } else {
                self.init(text: recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions")
            }
        }
    }

    private init(text: String.LocalizationValue) {
        self.text = AppLocalization.string(
            text, language: AppInterfaceLanguage(identifier: AppLocalization.resourceBundle.developmentLocalization ?? "en"))
        localizedText = LocalizedStringResource(text, bundle: .atURL(AppLocalization.resourceBundle.bundleURL))
        isFailure = false
    }

    private init(failure: String) {
        text = failure
        localizedText = nil
        isFailure = true
    }
}
