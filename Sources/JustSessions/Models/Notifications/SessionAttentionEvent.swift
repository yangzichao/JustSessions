import Foundation

/// A CLI that just started wanting you back.
struct SessionAttentionEvent: Equatable {
    let source: SessionAttentionSource
    let reason: SessionAttentionReason
}
