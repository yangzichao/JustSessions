import Foundation

/// What closing a plain terminal's tab does: ask each time, or close it without asking once you chose Don't ask again
/// in that dialog or in Settings. Its shell runs outside tmux, so closing always ends it.
enum PlainTerminalCloseChoice: String, CaseIterable, Identifiable, Sendable {
    case askEachTime
    case closeWithoutAsking

    var id: Self { self }
}
