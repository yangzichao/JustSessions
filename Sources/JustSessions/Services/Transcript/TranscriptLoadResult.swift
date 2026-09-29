import Foundation

enum TranscriptLoadResult: Sendable, Equatable {
    case loaded(TranscriptContent)
    case unsupported
}
