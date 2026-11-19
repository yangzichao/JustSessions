import Foundation

struct HostCheckFinding: Codable, Equatable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable {
        case passed
        case note
        case warning
        case problem
    }

    let id: HostCheckFindingID
    let status: Status
    let title: String
    let summary: String
    var hostOutput: String? = nil
    var commandToRunYourself: String? = nil
}
