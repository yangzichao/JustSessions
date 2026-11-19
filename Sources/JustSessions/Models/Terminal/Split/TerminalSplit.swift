import Foundation

struct TerminalSplit: Identifiable, Equatable {
    struct Sides: Equatable {
        var left: UUID
        var right: UUID

        func tabID(on side: Side) -> UUID {
            side == .left ? left : right
        }

        func side(of tabID: UUID) -> Side? {
            switch tabID {
            case left: .left
            case right: .right
            default: nil
            }
        }
    }

    enum Side {
        case left, right
    }

    enum Orientation: Equatable {
        case sideBySide, stacked

        var toggled: Orientation {
            self == .sideBySide ? .stacked : .sideBySide
        }
    }

    private static let groupKeyPrefixOfSplitsAcrossProjects = "split-view:"

    let id: UUID
    private(set) var tabIDs: Set<UUID>
    let groupKey: String
    var orientation: Orientation

    init(id: UUID = UUID(), tabIDs: (UUID, UUID), groupKey: String, orientation: Orientation = .sideBySide) {
        precondition(tabIDs.0 != tabIDs.1, "A split links two different tabs")
        self.id = id
        self.tabIDs = [tabIDs.0, tabIDs.1]
        self.groupKey = groupKey
        self.orientation = orientation
    }

    static func groupKey(ofSplitAcrossProjects id: UUID) -> String {
        groupKeyPrefixOfSplitsAcrossProjects + id.uuidString
    }

    static func isGroupKeyOfSplitAcrossProjects(_ groupKey: String) -> Bool {
        groupKey.hasPrefix(groupKeyPrefixOfSplitsAcrossProjects)
    }

    var spansProjects: Bool {
        groupKey == Self.groupKey(ofSplitAcrossProjects: id)
    }

    func contains(_ tabID: UUID) -> Bool {
        tabIDs.contains(tabID)
    }

    func partner(of tabID: UUID) -> UUID? {
        guard contains(tabID) else { return nil }
        return tabIDs.first { $0 != tabID }
    }

    func replacing(_ oldID: UUID, with newID: UUID) -> TerminalSplit {
        guard let partner = partner(of: oldID), partner != newID else { return self }
        return TerminalSplit(id: id, tabIDs: (partner, newID), groupKey: groupKey, orientation: orientation)
    }

    func regrouped(into groupKey: String) -> TerminalSplit {
        let tabIDs = Array(tabIDs)
        return TerminalSplit(id: id, tabIDs: (tabIDs[0], tabIDs[1]), groupKey: groupKey, orientation: orientation)
    }
}
