import Foundation
import Testing
@testable import JustSessions

/// The rules every change to the tab order keeps: the tabs of one group sit together, a split's two tabs are both
/// open and side by side, no tab is in two splits, and a split's group holds a tab of the project it is named for.
func expectSplitRules(_ strip: TerminalTabStrip, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(keepsGroupsTogether(strip.groupKeys), "groups together: \(strip.groupKeys)", sourceLocation: sourceLocation)
    let tabIDs = strip.tabIDs
    for split in strip.splits {
        let indices = tabIDs.indices.filter { split.contains(tabIDs[$0]) }
        #expect(indices.count == 2, "both tabs of a split are open", sourceLocation: sourceLocation)
        if indices.count == 2 {
            #expect(indices[1] == indices[0] + 1, "a split's tabs sit side by side", sourceLocation: sourceLocation)
        }
        let hasTabOfItsGroupsProject = strip.tabs.contains { $0.projectKey == split.groupKey && strip.groupKey(of: $0) == split.groupKey }
        #expect(hasTabOfItsGroupsProject, "a split's group \(split.groupKey) holds a tab of that project", sourceLocation: sourceLocation)
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

/// The rule check itself catches a key that comes back after another.
struct TerminalSplitRulesTests {
    @Test func groupsStayTogetherWhileNoKeyComesBackAfterAnother() {
        #expect(keepsGroupsTogether([]))
        #expect(keepsGroupsTogether(["/a", "/a", "/b", "/c", "/c"]))
        #expect(!keepsGroupsTogether(["/a", "/b", "/a"]))
        #expect(!keepsGroupsTogether(["/a", "/b", "/c", "/b"]))
    }
}
