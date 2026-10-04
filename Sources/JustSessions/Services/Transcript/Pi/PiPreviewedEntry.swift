import Foundation

/// The kinds of Pi session entries the preview shows. The first pass of `PiTranscriptReader` decodes only lines of
/// these kinds and the second pass shows each of them, so the two cannot disagree about which lines matter.
enum PiPreviewedEntry {
    case userMessage
    /// A command the user ran with `!`, or with `!!` to keep its output out of the model's context.
    case shellCommand
    case assistantMessage
    /// Shown only for its images, such as a screenshot; its text is left to the tool call that produced it.
    case toolResult
    /// Pi summarized older messages to free up its context window.
    case compaction
    /// The user went back to an earlier message and Pi summarized the branch they left.
    case branchSummary

    /// Pi writes each image part's type this way, without spaces.
    private static let imagePartMarker = Data("\"type\":\"image\"".utf8)

    /// Nil for entries the preview leaves out. `role` is the role of a `message` entry's message; other entry types
    /// ignore it.
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

    /// Whether this entry could show anything once `line` is decoded. Tool results make up most of a session's
    /// bytes and nearly all of them hold only text, so one is decoded only when its bytes mention an image part.
    func mightBeShown(in line: Data) -> Bool {
        self != .toolResult || line.range(of: Self.imagePartMarker) != nil
    }
}
