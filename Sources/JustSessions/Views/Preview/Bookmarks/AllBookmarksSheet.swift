import AppKit
import SwiftUI

struct AllBookmarksSheet: View {
    let store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var requiredTags: Set<String> = []
    @State private var editor = MessageBookmarkEditorRequests()
    @FocusState private var isSearchFocused: Bool

    private var list: AllBookmarksList {
        AllBookmarksList(
            bookmarks: store.messageBookmarks, query: MessageBookmarkQuery(searchText), requiredTags: requiredTags,
            conversation: store.conversation(withID:), title: store.title(for:))
    }

    var body: some View {
        let list = list
        ThemeSheetLayout(
            title: Text("All Bookmarks"),
            intro: Text("Search labels, tags, and messages, or type #tag. Choose a bookmark to read it."),
            width: ThemeSheetMetrics.wideWidth
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search bookmarks", text: $searchText)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .focused($isSearchFocused)
                    .accessibilityIdentifier("all-bookmarks.search")
                AllBookmarksTagFilter(tags: store.messageBookmarks.allTags, selected: $requiredTags)
                AllBookmarksRows(
                    list: list, store: store, language: AppInterfaceLanguage(identifier: locale.identifier),
                    onOpen: open, onEdit: { editor.open($1, in: $0) })
                if list.unlistedBookmarkCount > 0 {
                    Text(
                        list.unlistedBookmarkCount == 1
                            ? "1 bookmark belongs to a session no host lists now."
                            : "\(list.unlistedBookmarkCount) bookmarks belong to sessions no host lists now."
                    )
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                }
            }
        } footer: {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .onAppear { isSearchFocused = true }
        .messageBookmarkEditor(editor, store: store)
        .accessibilityIdentifier("all-bookmarks")
    }

    private func open(_ bookmark: MessageBookmark, in conversation: Conversation) {
        dismiss()
        SessionReadingWindowManager.shared.open(conversation, store: store, navigation: .bookmark(bookmark))
    }
}

private struct AllBookmarksTagFilter: View {
    let tags: [String]
    @Binding var selected: Set<String>

    var body: some View {
        if !tags.isEmpty {
            MessageBookmarkFlowLayout(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    let isSelected = selected.contains(tag)
                    Button {
                        if isSelected { selected.remove(tag) } else { selected.insert(tag) }
                    } label: {
                        Text(verbatim: "#" + tag)
                            .font(ThemeFont.caption)
                            .foregroundStyle(isSelected ? ThemePalette.inkForeground : ThemePalette.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(ThemePalette.trackFill),
                                in: RoundedRectangle(.small))
                    }
                    .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
                    .accessibilityLabel(Text(verbatim: "#" + tag))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Tags"))
        }
    }
}

private struct AllBookmarksRows: View {
    let list: AllBookmarksList
    let store: ConversationStore
    let language: AppInterfaceLanguage?
    let onOpen: (MessageBookmark, Conversation) -> Void
    let onEdit: (Conversation, MessageBookmark) -> Void

    var body: some View {
        if list.sections.isEmpty {
            Text(
                store.messageBookmarks.bookmarksByConversationID.isEmpty
                    ? "No bookmarks yet. Press ⌘D to bookmark a message."
                    : "No bookmarks match."
            )
            .font(ThemeFont.callout)
            .foregroundStyle(ThemePalette.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(list.sections) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            sessionHeader(section.conversation)
                            ForEach(section.bookmarks, id: \.letter) { bookmark in
                                AllBookmarksRow(
                                    bookmark: bookmark, speaker: speaker(of: bookmark, in: section.conversation),
                                    onOpen: { onOpen(bookmark, section.conversation) },
                                    onEdit: { onEdit(section.conversation, bookmark) },
                                    onRemove: { store.removeMessageBookmark(bookmark, in: section.conversation) })
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200, maxHeight: 420)
        }
    }

    private func sessionHeader(_ conversation: Conversation) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: store.title(for: conversation))
                .font(ThemeFont.callout.weight(.semibold))
                .foregroundStyle(ThemePalette.ink)
            Text(
                verbatim:
                    "\(conversation.provider.rawValue) · \(store.projectDisplayName(forProjectPath: conversation.projectDirectoryKey))"
            )
            .font(ThemeFont.detail)
            .foregroundStyle(ThemePalette.secondaryText)
        }
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
    }

    private func speaker(of bookmark: MessageBookmark, in conversation: Conversation) -> String {
        bookmark.kind == .user ? AppLocalization.string("You", language: language) : conversation.provider.rawValue
    }
}

private struct AllBookmarksRow: View {
    let bookmark: MessageBookmark
    let speaker: String
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: bookmark.letter)
                    .font(ThemeFont.caption.weight(.semibold))
                    .foregroundStyle(ThemePalette.secondaryText)
                    .frame(width: 16, height: 16)
                    .background(ThemePalette.trackFill, in: RoundedRectangle(.small))
                VStack(alignment: .leading, spacing: 2) {
                    if let label = bookmark.label {
                        Text(verbatim: label)
                            .font(ThemeFont.callout.weight(.medium))
                            .foregroundStyle(ThemePalette.ink)
                    }
                    Text(verbatim: "\(speaker): \(bookmark.snippet)")
                        .font(bookmark.label == nil ? ThemeFont.callout : ThemeFont.detail)
                        .foregroundStyle(bookmark.label == nil ? ThemePalette.ink : ThemePalette.secondaryText)
                    MessageBookmarkTagList(tags: bookmark.tags)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6, verticalPadding: 4, cornerRadius: .small))
        .contextMenu {
            Button("Edit bookmark \(bookmark.letter)…", action: onEdit)
            Button("Remove bookmark \(bookmark.letter)", action: onRemove)
        }
        .accessibilityLabel(Text(verbatim: TranscriptBookmarkMarker.accessibilityLabel(of: bookmark) + ", \(speaker): \(bookmark.snippet)"))
        .accessibilityAction(named: Text("Edit bookmark \(bookmark.letter)…"), onEdit)
        .accessibilityAction(named: Text("Remove bookmark \(bookmark.letter)"), onRemove)
    }
}

struct AllBookmarksPresenter: ViewModifier {
    let store: ConversationStore

    func body(content: Content) -> some View {
        let isPresented = Binding(get: { store.showsAllBookmarks }, set: { store.showsAllBookmarks = $0 })
        content
            .sheet(isPresented: isPresented) { AllBookmarksSheet(store: store) }
            .background { if store.showsAllBookmarks { Color.clear.dismissesOnClickOutside(isPresented: isPresented) } }
    }
}

@MainActor
enum AllBookmarksCommand {
    static func show(registry: WorkspaceWindowRegistry = .shared) {
        let workspaces = registry.stores.compactMap { store in registry.window(of: store).map { (store: store, window: $0) } }
        let frontmost = NSApp.orderedWindows.lazy.filter(\.isVisible)
            .compactMap { window in workspaces.first { $0.window === window } }.first
        guard let workspace = frontmost ?? workspaces.first(where: { $0.window.isMiniaturized }) else { return }
        if workspace.window.isMiniaturized { workspace.window.deminiaturize(nil) }
        workspace.window.makeKeyAndOrderFront(nil)
        if workspace.window.attachedSheet == nil { workspace.store.showsAllBookmarks = true }
    }
}
