import SwiftUI

struct ConversationSharingMenuItems: View {
    let selections: [ConversationExportSelection]
    @ObservedObject private var sharingController = ConversationSharingController.shared

    private var canShare: Bool {
        !selections.isEmpty && !sharingController.isSharing
            && selections.allSatisfy { TranscriptLoader.supportsReading($0.conversation.provider) }
    }

    var body: some View {
        let conversationLabel = selections.count == 1 ? "conversation" : "\(selections.count) conversations"
        Button("Copy \(conversationLabel)", systemImage: "doc.on.doc") {
            sharingController.copy(selections)
        }
        .disabled(!canShare)
        .help("Copy saved messages and tool-call summaries as Markdown")
        Menu("Export \(conversationLabel)", systemImage: "square.and.arrow.up") {
            Button("Markdown (.md)…") { sharingController.export(selections, format: .markdown) }
            Button("Plain text (.txt)…") { sharingController.export(selections, format: .plainText) }
        }
        .disabled(!canShare)
        .help("Save messages and tool-call summaries to a file")
    }
}
