import Foundation

/// Wording for a host where no supported CLI was found.
enum NewSessionProviderAvailability {
    static func noCLIFoundMessage(on host: SessionHost) -> String {
        let supportedCLINames = ConversationProvider.allCases
            .filter { $0.runs(on: host) }
            .map(\.executableName)
            .formatted(.list(type: .or))
        return host == .thisMac
            ? "No supported CLI found on this Mac. Install \(supportedCLINames), then refresh."
            : "No supported CLI found on \(host.displayName). Install \(supportedCLINames) there, then refresh."
    }
}
