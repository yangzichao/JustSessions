import Foundation

@testable import JustSessions

/// Output as `RemoteHostCheckScript` prints it, each answer under its marker line, after a shell profile's greeting.
func hostCheckScriptOutput(_ answers: KeyValuePairs<String, String>) -> String {
    "Welcome to devbox\n"
        + answers.map { key, answer in
            "\n\(RemoteHostCheckScript.marker) \(key)\n\(answer)\n"
        }.joined()
}

func hostCheckOutput(_ answers: KeyValuePairs<String, String>) -> RemoteHostCheckOutput {
    RemoteHostCheckOutput(hostCheckScriptOutput(answers))
}

func hostCheckContext(
    host: String = "devbox",
    shellStartup: RemoteShellStartup = .interactive,
    programs: [RemoteHostCheckProgram] = RemoteHostCheckProgram.all { _ in nil },
    session: HostCheckSession? = nil,
    providersWithSessions: Set<ConversationProvider> = []
) -> RemoteHostCheckContext {
    RemoteHostCheckContext(
        host: host,
        shellStartup: shellStartup,
        programs: programs,
        session: session,
        providersWithSessions: providersWithSessions
    )
}
