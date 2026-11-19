import Foundation

struct SessionActivityObservation: Equatable {
    let source: SessionAttentionSource
    let activity: CLIActivity?
}
