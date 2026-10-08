import Foundation

/// What a CLI is started with, on top of its own arguments and environment, so it reports its session.
struct LiveSessionReporterLaunch: Sendable, Equatable {
    let arguments: [String]
    let environment: [String: String]
}
