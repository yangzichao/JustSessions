import Foundation

/// What one activity sync read of a CLI running on this Mac.
struct SessionActivityObservation: Equatable {
    let source: SessionAttentionSource
    /// Nil when the CLI told nothing this time.
    let activity: CLIActivity?
}
