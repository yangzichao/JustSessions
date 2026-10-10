import Foundation

/// Opens a folder on an SSH host in a VS Code-family editor by running its command-line tool with `--folder-uri`.
/// The tool hands the folder to the running editor, or starts it, and exits.
enum RemoteSSHFolderOpener {
    static let timeout: TimeInterval = 30

    static func open(path: String, on destination: String, withCommandLineToolAt toolURL: URL) async throws {
        let arguments = ["--folder-uri", RemoteSSHFolderURI.string(destination: destination, path: path)]
        let result = await Task.detached {
            BoundedProcessRunner.result(
                ofExecutable: toolURL.path,
                arguments: arguments,
                includesStandardError: true,
                timeout: Self.timeout
            )
        }.value
        guard let result else { throw RemoteSSHFolderOpenError.didNotFinish }
        guard result.exitStatus == 0 else {
            throw RemoteSSHFolderOpenError.failed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
