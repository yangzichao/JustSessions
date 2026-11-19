import Foundation

enum PlainTerminalCloseChoice: String, CaseIterable, Identifiable, Sendable {
    case askEachTime
    case closeWithoutAsking

    var id: Self { self }
}
