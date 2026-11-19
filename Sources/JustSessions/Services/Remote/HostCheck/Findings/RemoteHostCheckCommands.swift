import Foundation

enum RemoteHostCheckCommands {
    static func ssh(_ host: String, _ remoteCommand: String) -> String? {
        guard isPlain(host), !remoteCommand.contains("'") else { return nil }
        return "ssh \(host) '\(remoteCommand)'"
    }

    static func inLoginShell(_ host: String, _ innerCommand: String, startup: RemoteShellStartup) -> String? {
        guard !innerCommand.contains("\""), !innerCommand.contains("$"), !innerCommand.contains("`") else { return nil }
        return ssh(host, "\(loginShellPrefix(startup)) \"\(innerCommand)\"")
    }

    static func shellStartup(_ host: String, startup: RemoteShellStartup) -> String? {
        guard isPlain(host) else { return nil }
        return "ssh -t \(host) '\(loginShellPrefix(startup)) \"echo Startup finished\"'"
    }

    static func isPlain(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "@._-/~+:,".contains($0)) }
    }

    private static func loginShellPrefix(_ startup: RemoteShellStartup) -> String {
        "env \(RemoteShellStartup.environmentVariable)=1 \"$SHELL\" " + startup.shellFlags
    }
}
