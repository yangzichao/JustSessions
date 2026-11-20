struct BookmarkableMessage: Sendable {
    let entry: TranscriptEntry
    let kind: MessageBookmark.Kind

    init?(_ entry: TranscriptEntry) {
        guard let kind = MessageBookmark.Kind(entry.content) else { return nil }
        self.entry = entry
        self.kind = kind
    }
}
