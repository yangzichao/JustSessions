import Foundation

/// The pinned projects, or the pinned sessions, in the order you put them. A newly pinned one goes last, and only a
/// drag in the sidebar moves one, so activity never reorders them.
struct PinnedOrder: Equatable {
    private(set) var ids: [String]
    /// Each pinned id's place in `ids`, for the sorts that ask on every comparison.
    private var placesByID: [String: Int]

    /// Keeps the first of any repeated id.
    init(_ ids: [String] = []) {
        var seenIDs = Set<String>()
        self.ids = ids.filter { seenIDs.insert($0).inserted }
        placesByID = Self.places(of: self.ids)
    }

    func contains(_ id: String) -> Bool {
        placesByID[id] != nil
    }

    /// Nil when `id` is not pinned.
    func place(of id: String) -> Int? {
        placesByID[id]
    }

    mutating func pin(_ id: String) {
        guard !contains(id) else { return }
        move(id, to: .last)
    }

    mutating func unpin(_ id: String) {
        guard contains(id) else { return }
        ids.removeAll { $0 == id }
        placesByID = Self.places(of: ids)
    }

    /// Pins `id` if it is not pinned yet, and puts it at `placement`. A neighbor that is not pinned puts it last.
    mutating func move(_ id: String, to placement: PinnedPlacement) {
        var reorderedIDs = ids.filter { $0 != id }
        let insertionIndex: Int = switch placement {
        case .before(let neighborID): reorderedIDs.firstIndex(of: neighborID) ?? reorderedIDs.endIndex
        case .after(let neighborID): reorderedIDs.firstIndex(of: neighborID).map { $0 + 1 } ?? reorderedIDs.endIndex
        case .last: reorderedIDs.endIndex
        }
        reorderedIDs.insert(id, at: insertionIndex)
        ids = reorderedIDs
        placesByID = Self.places(of: ids)
    }

    private static func places(of ids: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
    }
}
