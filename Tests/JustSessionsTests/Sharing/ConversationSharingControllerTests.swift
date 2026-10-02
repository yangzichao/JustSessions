import AppKit
import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ConversationSharingControllerTests {
    @Test func copiesSavedMessagesAfterTheMenuActionReturnsAndResetsBusyState() async throws {
        _ = NSApplication.shared
        let file = try TranscriptTestFiles.write([
            ["type": "user", "message": ["content": "Copy 完整对话"]],
            ["type": "assistant", "message": ["content": "```swift\nprint(\"🙂\")\n```"]],
        ])
        defer { try? FileManager.default.removeItem(at: file) }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Previous clipboard", forType: .string)
        let controller = ConversationSharingController(pasteboard: pasteboard)
        controller.copy([ConversationExportSelection(conversation: .fixture(sourceFile: file), title: "Custom title")])
        #expect(controller.isSharing)
        // Loading happens after the menu's synchronous action has finished.
        #expect(pasteboard.string(forType: .string) == "Previous clipboard")
        try await expectEventually { !controller.isSharing }
        let copiedText = try #require(pasteboard.string(forType: .string))
        #expect(copiedText.hasPrefix("# Custom title\n"))
        #expect(copiedText.contains("Copy 完整对话"))
        #expect(copiedText.contains("```swift\nprint(\"🙂\")\n```"))
    }
}
