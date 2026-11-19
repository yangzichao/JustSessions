import Foundation

@testable import JustSessions

enum TerminalTitlesSent {
    static func titles(inOutputFile output: URL) -> [String] {
        let text = (try? Data(contentsOf: output)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return text.matches(of: /\x1B\][02];([^\x07\x1B]*)/).map { String($0.output.1) }
    }

    static func lastActivity(inOutputFile output: URL, of provider: ConversationProvider) -> CLIActivity? {
        titles(inOutputFile: output).last.flatMap { RemoteCLIActivityTitle.activity(inTerminalTitle: $0, of: provider) }
    }
}
