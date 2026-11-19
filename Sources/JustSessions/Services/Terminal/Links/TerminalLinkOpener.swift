import AppKit

@MainActor
struct TerminalLinkOpener {
    let host: SessionHost
    let workingDirectory: String
    var openURL: (URL) -> Void = { NSWorkspace.shared.open($0) }
    var revealInFinder: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    var copyText: (String) -> Void = { text in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    var openInEditor: @MainActor (TerminalLinkLocalItem, InstalledExternalEditor) async throws -> Void = ExternalEditorFileOpener.open

    func target(of link: String) -> TerminalLinkTarget? {
        TerminalLinkTarget(link: link, host: host, workingDirectory: workingDirectory)
    }

    func open(_ target: TerminalLinkTarget) {
        guard canOpen(target) else { return }
        switch target {
        case .webAddress(let url): openURL(url)
        case .localItem(let item): openURL(item.url)
        case .remotePath: break
        }
    }

    func canOpen(_ target: TerminalLinkTarget) -> Bool {
        switch target {
        case .webAddress: true
        case .localItem(let item): LocalFileLinkSafety.canOpen(item.url)
        case .remotePath: false
        }
    }
}
