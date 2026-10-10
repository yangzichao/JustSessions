import Foundation

extension NativeCLICommandResolver {
    /// Your login shell in the folder. As a login shell it sets up PATH from your profile, the way a new Terminal
    /// window does, so PATH is left as inherited. It gets the color settings the CLIs get.
    func resolvePlainTerminal(
        projectPath: String,
        shellPath: String = LoginShellEnvironment.userLoginShellPath()
    ) throws -> NativeCLICommand {
        try requireProjectDirectory(projectPath)
        var environment = TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
        environment["SHELL"] = shellPath
        return NativeCLICommand(
            executablePath: shellPath,
            arguments: ["-l"],
            workingDirectory: projectPath,
            environment: NativeCLICommand.environmentEntries(environment)
        )
    }
}
