import AppKit

@MainActor
enum ExternalEditorFileOpener {
    nonisolated static let timeout: TimeInterval = 30

    static func open(_ item: TerminalLinkLocalItem, in editor: InstalledExternalEditor) async throws {
        if item.kind == .file, item.lineNumber != nil, let toolURL = editor.vsCodeFamilyCommandLineToolURL {
            try await goTo(item, withCommandLineToolAt: toolURL)
            return
        }
        _ = try await NSWorkspace.shared.open(
            [item.url],
            withApplicationAt: editor.applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private static func goTo(_ item: TerminalLinkLocalItem, withCommandLineToolAt toolURL: URL) async throws {
        let arguments = ["--goto", item.pathWithLineAndColumn]
        let result = await Task.detached {
            BoundedProcessRunner.result(
                ofExecutable: toolURL.path,
                arguments: arguments,
                includesStandardError: true,
                timeout: Self.timeout
            )
        }.value
        guard let result else { throw ExternalEditorCommandLineToolError.didNotFinish }
        guard result.exitStatus == 0 else {
            throw ExternalEditorCommandLineToolError.failed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
