import Foundation

struct LiveSessionReporterLaunch: Sendable, Equatable {
    let arguments: [String]
    let environment: [String: String]
}
