import Foundation
import Testing

@testable import JustSessions

/// The rules every change to the tab order keeps: the tabs of one group sit together, a split's two tabs are both
/// open and side by side, no tab is in two splits, a split of one project's tabs shows in that project's group, and
/// a split across projects shows in a group of its own that holds only its two tabs.
func expectSplitRules(_ strip: TerminalTabStrip, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(keepsGroupsTogether(strip.groupKeys), "groups together: \(strip.groupKeys)", sourceLocation: sourceLocation)
    let tabIDs = strip.tabIDs
    for split in strip.splits {
        let indices = tabIDs.indices.filter { split.contains(tabIDs[$0]) }
        #expect(indices.count == 2, "both tabs of a split are open", sourceLocation: sourceLocation)
        if indices.count == 2 {
            #expect(indices[1] == indices[0] + 1, "a split's tabs sit side by side", sourceLocation: sourceLocation)
        }
        let projectKeys = Set(strip.tabs.filter { split.contains($0.id) }.map(\.projectKey))
        if projectKeys.count == 1 {
            #expect(
                split.groupKey == projectKeys.first, "a split of one project shows in that project's group", sourceLocation: sourceLocation)
        } else {
            #expect(split.spansProjects, "a split across projects shows in a group of its own", sourceLocation: sourceLocation)
            let tabsInItsGroup = strip.tabs.filter { strip.groupKey(of: $0) == split.groupKey }.map(\.id)
            #expect(Set(tabsInItsGroup) == split.tabIDs, "a split's own group holds only its two tabs", sourceLocation: sourceLocation)
        }
    }
    let splitTabIDs = strip.splits.flatMap(\.tabIDs)
    #expect(Set(splitTabIDs).count == splitTabIDs.count, "no tab is in two splits", sourceLocation: sourceLocation)
}

@MainActor
func expectSplitRules(_ store: ConversationStore, sourceLocation: SourceLocation = #_sourceLocation) {
    expectSplitRules(store.tabStrip, sourceLocation: sourceLocation)
    #expect(store.tabGroupKeys == store.tabStrip.groupKeys, sourceLocation: sourceLocation)
}

/// Each key's tabs sit side by side, with no other key's tab between them.
func keepsGroupsTogether(_ tabGroupKeys: [String]) -> Bool {
    var finishedKeys: Set<String> = []
    for (index, groupKey) in tabGroupKeys.enumerated() where index > 0 && tabGroupKeys[index - 1] != groupKey {
        finishedKeys.insert(tabGroupKeys[index - 1])
        if finishedKeys.contains(groupKey) { return false }
    }
    return true
}

/// A split across projects between the two tabs, in its own group, as `TerminalTabStrip.addSplit` makes one.
func splitAcrossProjects(_ tabIDs: (UUID, UUID)) -> TerminalSplit {
    let id = UUID()
    return TerminalSplit(id: id, tabIDs: tabIDs, groupKey: TerminalSplit.groupKey(ofSplitAcrossProjects: id))
}

/// The rule check itself catches a key that comes back after another.
struct TerminalSplitRulesTests {
    @Test func groupsStayTogetherWhileNoKeyComesBackAfterAnother() {
        #expect(keepsGroupsTogether([]))
        #expect(keepsGroupsTogether(["/a", "/a", "/b", "/c", "/c"]))
        #expect(!keepsGroupsTogether(["/a", "/b", "/a"]))
        #expect(!keepsGroupsTogether(["/a", "/b", "/c", "/b"]))
    }

    @Test func aSplitsOwnGroupKeyIsNoProjectsKey() {
        let split = splitAcrossProjects((UUID(), UUID()))

        #expect(split.spansProjects)
        #expect(TerminalSplit.isGroupKeyOfSplitAcrossProjects(split.groupKey))
        #expect(!TerminalSplit.isGroupKeyOfSplitAcrossProjects("/Users/me/split-view:app"))
        #expect(!TerminalSplit.isGroupKeyOfSplitAcrossProjects("ssh://box/home/me/app"))
        #expect(!TerminalSplit(tabIDs: (UUID(), UUID()), groupKey: "/a").spansProjects)
    }
}
