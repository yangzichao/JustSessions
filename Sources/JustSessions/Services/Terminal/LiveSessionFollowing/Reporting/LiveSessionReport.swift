import Foundation

struct LiveSessionReport: Sendable, Equatable {
    let sessionID: String?
    let sessionFile: URL?
    let activity: CLIActivity?

    init?(jsonData: Data, processID: Int32) {
        guard let object = ConversationMetadata.object(from: jsonData),
            (object["pid"] as? NSNumber)?.int32Value == processID
        else { return nil }
        sessionID = object["sessionId"] as? String
        sessionFile = (object["sessionFile"] as? String).flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
        activity =
            sessionID == nil
            ? nil
            : Self.activity(named: object["activity"] as? String, waitingFor: object["waitingFor"] as? String)
    }

    static func activity(named name: String?, waitingFor: String?) -> CLIActivity? {
        switch name {
        case "working": .working
        case "waiting": .needsInput(reportedReason: waitingFor)
        case "idle": .idle
        default: nil
        }
    }
}
