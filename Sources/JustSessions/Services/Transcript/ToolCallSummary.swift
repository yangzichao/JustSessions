import Foundation

/// One-line descriptions of tool calls, such as "Bash · git status".
enum ToolCallSummary {
    static let maximumLength = 240

    private static let descriptiveArgumentKeys = [
        "command", "cmd", "file_path", "path", "pattern", "url", "query",
        "description", "title", "task_name", "message", "prompt",
    ]

    static func summary(toolName: String, arguments: [String: Any]) -> String {
        let detail = descriptiveArgumentKeys.lazy.compactMap { describe(arguments[$0]) }.first
            ?? arguments.keys.sorted().lazy.compactMap { describe(arguments[$0]) }.first
        return line(toolName: toolName, detail: detail)
    }

    static func summary(toolName: String, freeformInput: String) -> String {
        line(toolName: toolName, detail: freeformInput)
    }

    private static func describe(_ value: Any?) -> String? {
        switch value {
        case let text as String: text
        case let parts as [String]: parts.joined(separator: " ")
        default: nil
        }
    }

    private static func line(toolName: String, detail: String?) -> String {
        let firstDetailLine = detail?
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let firstDetailLine else { return toolName }
        let text = "\(toolName) · \(firstDetailLine)"
        return text.count > maximumLength ? String(text.prefix(maximumLength)) + "…" : text
    }
}
