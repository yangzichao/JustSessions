import Observation
import SwiftUI

struct MessageBookmarkEditRequest: Identifiable {
    let id = UUID()
    let conversation: Conversation
    let bookmark: MessageBookmark
}

@MainActor
@Observable
final class MessageBookmarkEditorRequests {
    var request: MessageBookmarkEditRequest?

    func open(_ bookmark: MessageBookmark, in conversation: Conversation) {
        request = MessageBookmarkEditRequest(conversation: conversation, bookmark: bookmark)
    }
}

struct MessageBookmarkEditorPresenter: ViewModifier {
    let requests: MessageBookmarkEditorRequests
    let store: ConversationStore?

    func body(content: Content) -> some View {
        // Read here, so this body follows the request; a binding alone isn't read until the sheet would show.
        let isRequested = requests.request != nil
        let request = Binding(get: { requests.request }, set: { requests.request = $0 })
        content
            .sheet(item: request) { request in
                if let store { MessageBookmarkEditorSheet(store: store, request: request) }
            }
            .background { if isRequested { Color.clear.dismissesOnClickOutside(item: request) } }
    }
}

extension View {
    func messageBookmarkEditor(_ requests: MessageBookmarkEditorRequests, store: ConversationStore?) -> some View {
        modifier(MessageBookmarkEditorPresenter(requests: requests, store: store))
    }
}

struct MessageBookmarkEditorSheet: View {
    let store: ConversationStore
    let request: MessageBookmarkEditRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var label: String
    @State private var typedTags: String

    init(store: ConversationStore, request: MessageBookmarkEditRequest) {
        self.store = store
        self.request = request
        let saved = Self.savedBookmark(request.bookmark, in: request.conversation, store: store) ?? request.bookmark
        _label = State(initialValue: saved.label ?? "")
        _typedTags = State(initialValue: saved.tags.isEmpty ? "" : MessageBookmarkDetails.typedText(of: saved.tags) + " ")
    }

    private static func savedBookmark(
        _ bookmark: MessageBookmark, in conversation: Conversation,
        store: ConversationStore
    ) -> MessageBookmark? {
        store.messageBookmarks.bookmarks(forConversationID: conversation.id)
            .first { $0.letter == bookmark.letter && $0.entryID == bookmark.entryID }
    }

    private var saved: MessageBookmark? { Self.savedBookmark(request.bookmark, in: request.conversation, store: store) }

    private var speaker: String {
        request.bookmark.kind == .user
            ? AppLocalization.string("You", language: AppInterfaceLanguage(identifier: locale.identifier))
            : request.conversation.provider.rawValue
    }

    var body: some View {
        let isGone = saved == nil
        ThemeSheetLayout(
            title: Text("Bookmark \(request.bookmark.letter)"),
            intro: Text(verbatim: "\(speaker): \(request.bookmark.menuSnippet)"),
            width: ThemeSheetMetrics.compactWidth
        ) {
            VStack(alignment: .leading, spacing: ThemeSheetMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Label").font(ThemeFont.fieldLabel)
                    TextField("A name to know it by", text: $label)
                        .textFieldStyle(ThemedTextFieldStyle())
                        .accessibilityLabel("Label")
                        .accessibilityIdentifier("bookmark-editor.label")
                        .onSubmit(save)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags").font(ThemeFont.fieldLabel)
                    TextField("#idea #todo", text: $typedTags)
                        .textFieldStyle(ThemedTextFieldStyle())
                        .accessibilityLabel("Tags")
                        .accessibilityIdentifier("bookmark-editor.tags")
                        .onSubmit(save)
                    MessageBookmarkTagSuggestions(suggestions: suggestions, onChoose: addTag)
                    Text("Separate tags with spaces or commas. Search for #tag in the sidebar or in All Bookmarks.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isGone {
                    Text("This bookmark was removed in another window.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.warningText)
                }
            }
        } footer: {
            Button("Remove bookmark", role: .destructive) {
                if let saved { store.removeMessageBookmark(saved, in: request.conversation) }
                dismiss()
            }
            .disabled(isGone)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save", action: save)
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(isGone)
        }
        .accessibilityIdentifier("bookmark-editor")
    }

    private var suggestions: [String] {
        MessageBookmarkTagTyping.suggestions(from: store.messageBookmarks.allTags, typed: typedTags)
    }

    private func addTag(_ tag: String) {
        typedTags = MessageBookmarkTagTyping.adding(tag, to: typedTags)
    }

    private func save() {
        guard let saved else { return }
        store.setMessageBookmarkDetails(
            of: saved, label: label, tags: MessageBookmarkDetails.tags(fromTyped: typedTags),
            in: request.conversation)
        dismiss()
    }
}

private struct MessageBookmarkTagSuggestions: View {
    let suggestions: [String]
    let onChoose: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            MessageBookmarkFlowLayout(spacing: 4) {
                ForEach(suggestions, id: \.self) { tag in
                    Button {
                        onChoose(tag)
                    } label: {
                        MessageBookmarkTagChip(tag: tag)
                    }
                    .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
                    .help("Add #\(tag)")
                    .accessibilityLabel(Text("Add tag \(tag)"))
                }
            }
        }
    }
}
