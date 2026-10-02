import SwiftUI

struct ConversationSharingMenuItems: View {
    let selections: [ConversationExportSelection]
    @ObservedObject private var sharingController = ConversationSharingController.shared

    private var canShare: Bool {
        !selections.isEmpty && !sharingController.isSharing
            && selections.allSatisfy { TranscriptLoader.supportsReading($0.conversation.provider) }
    }

    var body: some View {
        Button(copyTitle, systemImage: "doc.on.doc") {
            sharingController.copy(selections)
        }
        .disabled(!canShare)
        .help("Copy saved messages and tool-call summaries as Markdown")
        Menu(exportTitle, systemImage: "square.and.arrow.up") {
            Button("Markdown (.md)…") { sharingController.export(selections, format: .markdown) }
            Button("Plain text (.txt)…") { sharingController.export(selections, format: .plainText) }
        }
        .disabled(!canShare)
        .help("Save messages and tool-call summaries to a file")
    }

    private var copyTitle: LocalizedStringKey {
        selections.count == 1 ? "Copy conversation" : "Copy \(selections.count) conversations"
    }

    private var exportTitle: LocalizedStringKey {
        selections.count == 1 ? "Export conversation" : "Export \(selections.count) conversations"
    }
}
