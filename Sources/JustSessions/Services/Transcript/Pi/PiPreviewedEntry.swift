/// The kinds of Pi session entries the preview shows. The first pass of `PiTranscriptReader` decodes only lines of
/// these kinds and the second pass shows each of them, so the two cannot disagree about which lines matter.
enum PiPreviewedEntry {
    case userMessage
    /// A command the user ran with `!`, or with `!!` to keep its output out of the model's context.
    case shellCommand
    case assistantMessage
    /// Pi summarized older messages to free up its context window.
    case compaction
    /// The user went back to an earlier message and Pi summarized the branch they left.
    case branchSummary

    /// Nil for entries the preview leaves out. `role` is the role of a `message` entry's message; other entry types
    /// ignore it.
    init?(entryType: String, role: String?) {
        switch (entryType, role) {
        case ("message", "user"): self = .userMessage
        case ("message", "bashExecution"): self = .shellCommand
        case ("message", "assistant"): self = .assistantMessage
        case ("compaction", _): self = .compaction
        case ("branch_summary", _): self = .branchSummary
        default:
            // Tool results are shown through the tool call that produced them, and system messages carry the prompt
            // and tools, not conversation. Extension messages (`custom_message`) are context injected for the model,
            // like the tagged text the other readers leave out; the remaining entry types record settings, labels,
            // names, and usage.
            return nil
        }
    }
}
