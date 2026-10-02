import Foundation

/// The entries of a Pi session that make up its current conversation. Pi links each entry to its parent and stores
/// no pointer to where the user is in that tree: the last entry is the current one, and the conversation is the chain
/// of parents from it back to the root. Entries on branches the user left behind are not part of it.
enum PiActiveBranch {
    /// `links` are in file order, and so is the result. Sessions from before Pi linked entries (version 1) have no
    /// ids, so all of their entries are kept. A parent that is missing or loops back ends the chain.
    static func entries(in links: [PiEntryLink]) -> [PiEntryLink] {
        let linkedEntries = links.filter { $0.id != nil }
        guard !linkedEntries.isEmpty else { return links }

        var positionsByID: [String: Int] = [:]
        for (position, link) in linkedEntries.enumerated() {
            // A repeated id means the later entry, as in Pi.
            if let id = link.id { positionsByID[id] = position }
        }
        var visitedPositions = Set<Int>()
        var branch: [PiEntryLink] = []
        var currentPosition: Int? = linkedEntries.count - 1
        while let position = currentPosition, visitedPositions.insert(position).inserted {
            let link = linkedEntries[position]
            branch.append(link)
            currentPosition = link.parentID.flatMap { positionsByID[$0] }
        }
        // Pi appends each entry after its parent, so file order is conversation order.
        return branch.sorted { $0.lineIndex < $1.lineIndex }
    }
}
