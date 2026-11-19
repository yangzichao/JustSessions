import Foundation

enum MessageBookmarkLocation: Equatable {
    case found(TranscriptEntry)
    /// Its record is covered by the loaded entries, or lies past the session's first or last, without its message.
    case missing(landingEntryID: Int)
    case notLoaded
}

enum MessageBookmarkNavigation {
    static let snippetLength = 80
    /// How much of a row must be on screen for its message to be the one being read. A jump leaves 6 points of the entry
    /// above its target in view (TranscriptScrollPositionController.restorePositionIfNeeded, offset -6).
    static let minimumVisibleHeight: CGFloat = 16

    /// The head of the text Find sees (prepared Markdown's plain text), whitespace collapsed, at most 80 characters.
    static func snippet(of entry: TranscriptEntry) -> String? {
        guard MessageBookmark.Kind(entry.content) != nil else { return nil }
        return collapsedHead(of: TranscriptSearchSegments.texts(in: entry)).snippet
    }

    /// Each segment's first 320 characters' words, one space apart, until they count 80 characters; see `SnippetWords`.
    static func collapsedHead(of segments: [String]) -> (snippet: String, isCut: Bool) {
        var words = SnippetWords()
        for segment in segments where words.add(segment) { break }
        return (String(words.text.prefix(snippetLength)), words.isCut)
    }

    /// Same kind, and the current text starts with the first 40 characters saved, ignoring case: a reply grows while it
    /// streams, and a later Markdown change may alter the end of the head.
    static func matches(_ bookmark: MessageBookmark, _ entry: TranscriptEntry) -> Bool {
        guard MessageBookmark.Kind(entry.content) == bookmark.kind, let current = snippet(of: entry) else { return false }
        return current.lowercased().hasPrefix(bookmark.snippet.prefix(40).lowercased())
    }

    /// Page `records` are index positions, not record numbers (TranscriptPage.swift:19-21; Pi and Antigravity differ),
    /// so coverage is judged by the loaded entries' records. A record never spans two pages (TranscriptPageReader.swift:4).
    static func locate(_ bookmark: MessageBookmark, in entries: [TranscriptEntry], hasEarlier: Bool, hasLater: Bool)
        -> MessageBookmarkLocation
    {
        guard let first = entries.first, let last = entries.last else { return .notLoaded }
        let record = TranscriptPageIdentity.record(for: bookmark.entryID)
        let isCovered =
            (record >= TranscriptPageIdentity.record(for: first.id) || !hasEarlier)
            && (record <= TranscriptPageIdentity.record(for: last.id) || !hasLater)
        guard isCovered else { return .notLoaded }
        if let exact = entries.first(where: { $0.id == bookmark.entryID }), matches(bookmark, exact) { return .found(exact) }
        // `part` shifts when an earlier part of the record appears or goes, as while an OpenCode message streams.
        if let moved = entries.first(where: { TranscriptPageIdentity.record(for: $0.id) == record && matches(bookmark, $0) }) {
            return .found(moved)
        }
        return .missing(landingEntryID: entries.first { $0.id >= bookmark.entryID }?.id ?? last.id)
    }

    static func bookmark(after origin: Int?, in bookmarks: [MessageBookmark]) -> MessageBookmark? {
        guard let origin else { return bookmarks.first }
        return bookmarks.first { $0.entryID > origin } ?? bookmarks.first
    }

    static func bookmark(before origin: Int?, in bookmarks: [MessageBookmark]) -> MessageBookmark? {
        guard let origin else { return bookmarks.last }
        return bookmarks.last { $0.entryID < origin } ?? bookmarks.last
    }

    /// Rules 1–3 of "the message being read": the seek target, then the first message with `minimumVisibleHeight` on
    /// screen, then the last message above the first visible entry. `visibleEntryIDs` are those with that much on screen.
    /// The message whose stretch of the reader `entryID`'s row is in: that entry when it is your message or the CLI's
    /// reply, else the nearest such above it, or below when none is above, as for a tool run or a note (RDR-48).
    static func message(at entryID: Int, in entries: [TranscriptEntry]) -> TranscriptEntry? {
        func isMessage(_ entry: TranscriptEntry) -> Bool { MessageBookmark.Kind(entry.content) != nil }
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return nil }
        return entries[...index].last(where: isMessage) ?? entries[index...].first(where: isMessage)
    }

    static func messageBeingRead(in entries: [TranscriptEntry], visibleEntryIDs: [Int], seekTarget: Int?) -> TranscriptEntry? {
        func isMessage(_ entry: TranscriptEntry) -> Bool { MessageBookmark.Kind(entry.content) != nil }
        if let seekTarget, let entry = entries.first(where: { $0.id == seekTarget }), isMessage(entry) { return entry }
        let visible = Set(visibleEntryIDs)
        if let shown = entries.first(where: { visible.contains($0.id) && isMessage($0) }) { return shown }
        guard let top = visibleEntryIDs.first, let topIndex = entries.firstIndex(where: { $0.id == top }) else { return nil }
        return entries[..<topIndex].last(where: isMessage)
    }
}

/// `collapsedHead`'s words as `split(whereSeparator: \.isWhitespace)` gives them, in one pass that stops once they're
/// enough (PERF-90). ASCII goes byte by byte, where each byte but CR is one Character; anything else by Character.
private struct SnippetWords {
    static let cut = MessageBookmarkNavigation.snippetLength * 4
    var text = ""
    /// Each word's length plus one, as the snippet counts them.
    var length = 0
    /// A segment's 320th character came before the words counted 80, or cut the last of them: text past it could
    /// change the snippet.
    var isCut = false

    /// True once the words count the snippet's length.
    mutating func add(_ segment: String) -> Bool {
        if let done = addASCII(segment) { return done }
        return addCharacters(segment)
    }

    /// Nil, adding nothing, at a CR or a byte past ASCII before the words end, or right after the cut, where it could
    /// join the last Character.
    private mutating func addASCII(_ segment: String) -> Bool? {
        var bytes: [UInt8] = []
        var count = length
        var scanned = 0
        var inWord = false
        var reachedCut = false
        var done = false
        for byte in segment.utf8 {
            if scanned == Self.cut {
                guard byte < 0x80 else { return nil }
                reachedCut = true
                break
            }
            guard byte < 0x80, byte != UInt8(ascii: "\r") else { return nil }
            scanned += 1
            if byte == UInt8(ascii: " ") || (0x09...0x0D).contains(byte) {
                guard inWord else { continue }
                inWord = false
                count += 1
                if count >= MessageBookmarkNavigation.snippetLength {
                    done = true
                    break
                }
            } else {
                if !inWord, !text.isEmpty || !bytes.isEmpty { bytes.append(UInt8(ascii: " ")) }
                inWord = true
                bytes.append(byte)
                count += 1
            }
        }
        text += String(decoding: bytes, as: UTF8.self)
        length = count
        return finish(inWord: inWord, reachedCut: reachedCut, done: done)
    }

    private mutating func addCharacters(_ segment: String) -> Bool {
        var index = segment.startIndex
        var wordStart: String.Index?
        var scanned = 0
        var reachedCut = false
        var done = false
        while index < segment.endIndex {
            if scanned == Self.cut {
                reachedCut = true
                break
            }
            scanned += 1
            let next = segment.index(after: index)
            if !segment[index].isWhitespace {
                if wordStart == nil { wordStart = index }
                length += 1
            } else if let start = wordStart {
                append(segment[start..<index])
                wordStart = nil
                length += 1
                if length >= MessageBookmarkNavigation.snippetLength {
                    done = true
                    break
                }
            }
            index = next
        }
        if let start = wordStart { append(segment[start..<index]) }
        return finish(inWord: wordStart != nil, reachedCut: reachedCut, done: done)
    }

    private mutating func append(_ word: Substring) {
        if !text.isEmpty { text += " " }
        text += word
    }

    /// Counts the word the segment's end or its cut left open.
    private mutating func finish(inWord: Bool, reachedCut: Bool, done: Bool) -> Bool {
        if reachedCut { isCut = true }
        guard inWord else { return done }
        length += 1
        return length >= MessageBookmarkNavigation.snippetLength
    }
}
