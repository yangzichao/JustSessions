import Foundation

/// What the sidebar says under a host that lists no projects: that its refresh is running or failed, or that the
/// filters and search left nothing.
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
        waitingFilter: SessionWaitingFilter
    ) {
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
            } else if waitingFilter == .waitingForYou {
                // Only Claude Code, Codex, Pi, and OpenCode on this Mac tell what they are doing, so say so rather
                // than suggest nothing else waits.
                self.init(text: host == .thisMac
                    ? "No Claude Code, Codex, Pi, or OpenCode session is waiting for you"
                    : "SSH hosts don't tell when a session waits for you")
            } else {
                self.init(text: recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions")
            }
        }
    }

    private init(text: String.LocalizationValue) {
        self.text = AppLocalization.string(text, language: AppInterfaceLanguage(identifier: AppLocalization.resourceBundle.developmentLocalization ?? "en"))
        localizedText = LocalizedStringResource(text, bundle: .atURL(AppLocalization.resourceBundle.bundleURL))
        isFailure = false
    }

    private init(failure: String) {
        text = failure
        localizedText = nil
        isFailure = true
    }
}
