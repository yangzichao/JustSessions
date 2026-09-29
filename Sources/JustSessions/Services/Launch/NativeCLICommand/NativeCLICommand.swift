import Foundation

struct NativeCLICommand {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: String
    let environment: [String]

    func appendingArguments(_ extraArguments: [String]) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: executablePath,
            arguments: arguments + extraArguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
    }

    /// `variables` as the sorted `NAME=value` entries `environment` holds.
    static func environmentEntries(_ variables: [String: String]) -> [String] {
        variables.map { "\($0.key)=\($0.value)" }.sorted()
    }

    /// `environment` as a dictionary, for running the same executable outside a terminal.
    var environmentVariables: [String: String] {
        environment.reduce(into: [String: String]()) { variables, entry in
            guard let separator = entry.firstIndex(of: "=") else { return }
            variables[String(entry[..<separator])] = String(entry[entry.index(after: separator)...])
        }
    }
}
