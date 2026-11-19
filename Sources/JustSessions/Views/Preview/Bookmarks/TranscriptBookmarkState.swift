import AppKit
import Observation

enum TranscriptBookmarkNotice: Equatable {
    case noBookmarks, allLettersInUse, nothingToBookmark
    case missing(MessageBookmark)

    var hidesByItself: Bool { if case .missing = self { false } else { true } }

    func text(language: AppInterfaceLanguage?) -> String {
        switch self {
        case .noBookmarks:
            AppLocalization.string(
                "No bookmarks in this conversation. Press ⌘D to bookmark the message you're reading.", language: language)
        case .allLettersInUse: AppLocalization.string("All 26 letters are in use. Remove a bookmark to add another.", language: language)
        case .nothingToBookmark: AppLocalization.string("Only your messages and the CLI's replies can be bookmarked.", language: language)
        case .missing(let bookmark):
            AppLocalization.string(
                "Bookmark \(bookmark.letter)'s message is no longer in this conversation. This is where it was.", language: language)
        }
    }
}

@MainActor
@Observable
final class TranscriptBookmarkState {
    nonisolated static let hintDuration: Duration = .seconds(4)

    @ObservationIgnored private(set) var loadingJump: MessageBookmark?
    @ObservationIgnored private(set) var loadingJumpCount = 0
    @ObservationIgnored private(set) var loadingEntryJump: Int?
    private(set) var notice: TranscriptBookmarkNotice?
    @ObservationIgnored let editor = MessageBookmarkEditorRequests()
    @ObservationIgnored let hover = TranscriptBookmarkHover()
    @ObservationIgnored let target = TranscriptBookmarkTarget()
    @ObservationIgnored private var noticeHidingTask: Task<Void, Never>?
    @ObservationIgnored private var carriedSeekTarget: Int?

    func startLoadingJump(_ bookmark: MessageBookmark) {
        loadingEntryJump = nil
        loadingJump = bookmark
        loadingJumpCount += 1
    }
    func startLoadingEntryJump(_ entryID: Int) {
        loadingJump = nil
        loadingEntryJump = entryID
        loadingJumpCount += 1
    }
    func cancelLoadingJump() {
        loadingJump = nil
        loadingEntryJump = nil
    }
    @discardableResult func finishLoadingJump() -> MessageBookmark? {
        defer { loadingJump = nil }
        return loadingJump
    }
    @discardableResult func finishLoadingEntryJump() -> Int? {
        defer { loadingEntryJump = nil }
        return loadingEntryJump
    }

    func show(_ notice: TranscriptBookmarkNotice) {
        self.notice = notice
        noticeHidingTask?.cancel()
        noticeHidingTask = nil
        if notice.hidesByItself {
            noticeHidingTask = Task { [weak self] in
                try? await Task.sleep(for: Self.hintDuration)
                guard !Task.isCancelled, self?.notice == notice else { return }
                self?.notice = nil
            }
        }
        announce(notice.text(language: nil))
    }

    func dismissNotice() {
        noticeHidingTask?.cancel()
        noticeHidingTask = nil
        if notice != nil { notice = nil }
    }

    /// VoiceOver doesn't follow the reader's scroll, so a jump and each notice are spoken.
    func announce(_ text: String) { Self.announce(text) }

    static func announce(_ text: String) {
        guard let application = NSApp else { return }
        NSAccessibility.post(
            element: application, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func carrySeekTarget(_ entryID: Int) { carriedSeekTarget = entryID }
    func takeCarriedSeekTarget() -> Int? {
        defer { carriedSeekTarget = nil }
        return carriedSeekTarget
    }
}
