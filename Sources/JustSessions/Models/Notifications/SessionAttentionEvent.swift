import Foundation

struct SessionAttentionEvent: Equatable {
    let source: SessionAttentionSource
    let reason: SessionAttentionReason
}
