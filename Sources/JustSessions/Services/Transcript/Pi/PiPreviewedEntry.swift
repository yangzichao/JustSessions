import Foundation

enum PiPreviewedEntry {
    case userMessage
    case shellCommand
    case assistantMessage
    case toolResult
    case compaction
    case branchSummary

    /// Pi writes each image part's type this way, without spaces.
    private static let imagePartMarker = Data("\"type\":\"image\"".utf8)

    init?(entryType: String, role: String?) {
        switch (entryType, role) {
        case ("message", "user"): self = .userMessage
        case ("message", "bashExecution"): self = .shellCommand
        case ("message", "assistant"): self = .assistantMessage
        case ("message", "toolResult"): self = .toolResult
        case ("compaction", _): self = .compaction
        case ("branch_summary", _): self = .branchSummary
        default:
            // System messages carry the prompt and tools, not conversation. Extension messages (`custom_message`)
            // are context injected for the model, like the tagged text the other readers leave out; the remaining
            // entry types record settings, labels, names, and usage.
            return nil
        }
    }

    func mightBeShown(in line: Data) -> Bool {
        self != .toolResult || line.range(of: Self.imagePartMarker) != nil
    }
}
