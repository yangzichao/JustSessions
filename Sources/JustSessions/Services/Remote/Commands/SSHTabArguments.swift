import Foundation

struct SSHTabArguments: Equatable, Sendable {
    let loginOptions: [String]
    let optionsAndRemoteCommand: [String]

    var all: [String] { ["-t"] + loginOptions + optionsAndRemoteCommand }
    var goesThroughLogin: Bool { !loginOptions.isEmpty }

    func throughLogin(options loginOptions: [String]) -> SSHTabArguments {
        SSHTabArguments(loginOptions: loginOptions, optionsAndRemoteCommand: optionsAndRemoteCommand)
    }
}

extension NativeCLICommand {
    init(sshTab arguments: SSHTabArguments, environment: [String]) {
        self.init(
            executablePath: "/usr/bin/ssh",
            arguments: arguments.all,
            workingDirectory: NSHomeDirectory(),
            environment: environment,
            sshTabArguments: arguments
        )
    }

    var goesThroughSSHLogin: Bool { sshTabArguments?.goesThroughLogin == true }
}
