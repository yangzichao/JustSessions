import AppKit
import Combine
import UniformTypeIdentifiers

/// Keeps Copy and Export running after a transient context menu closes.
@MainActor
final class ConversationSharingController: ObservableObject {
    static let shared = ConversationSharingController()
    @Published private(set) var isSharing = false
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func copy(_ selections: [ConversationExportSelection]) {
        perform(selections, failureTitle: "Could not copy conversation") { [pasteboard] document, _ in
            let text = try await document.text(in: .markdown)
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else {
                throw ConversationExportError.clipboardUnavailable
            }
        }
    }

    func export(_ selections: [ConversationExportSelection], format: ConversationExportFormat) {
        perform(selections, failureTitle: "Could not export conversation") { document, window in
            let panel = NSSavePanel()
            panel.title = selections.count == 1
                ? AppLocalization.string("Export conversation") : AppLocalization.string("Export conversations")
            panel.prompt = AppLocalization.string("Export")
            panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = document.suggestedFileName(for: format)
            let response = await Self.show(panel, in: window)
            guard response == .OK, let destination = panel.url else { return }
            try await document.write(to: destination, format: format)
        }
    }

    private func perform(
        _ selections: [ConversationExportSelection],
        failureTitle: String.LocalizationValue,
        operation: @escaping @MainActor (ConversationExportDocument, NSWindow?) async throws -> Void
    ) {
        guard !isSharing else { return }
        isSharing = true
        let window = NSApp.keyWindow
        Task {
            defer { isSharing = false }
            do {
                let document = try await ConversationExportDocument.load(selections)
                try await operation(document, window)
            } catch is CancellationError {
                // A cancelled read leaves the clipboard and destination unchanged.
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = AppLocalization.string(failureTitle)
                alert.informativeText = error.localizedDescription
                if let window, window.isVisible, window.attachedSheet == nil {
                    let clickOutsideMonitor = SheetClickOutsideMonitor(window: window) {
                        window.endSheet(alert.window)
                        return true
                    }
                    await alert.beginSheetModal(for: window)
                    clickOutsideMonitor.stop()
                } else {
                    alert.runModal()
                }
            }
        }
    }

    private static func show(_ panel: NSSavePanel, in window: NSWindow?) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let window, window.isVisible, window.attachedSheet == nil {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
    }
}
