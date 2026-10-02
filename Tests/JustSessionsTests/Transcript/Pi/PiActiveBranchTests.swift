import Foundation
import Testing
@testable import JustSessions

struct PiActiveBranchTests {
    /// Links numbered by line from 1, as `(id, parent id)`.
    private static func links(_ pairs: [(String?, String?)]) -> [PiEntryLink] {
        pairs.enumerated().map { offset, pair in
            PiEntryLink(lineIndex: offset + 1, id: pair.0, parentID: pair.1, mightBeShown: true)
        }
    }

    private static func lineIndices(_ pairs: [(String?, String?)]) -> [Int] {
        PiActiveBranch.entries(in: links(pairs)).map(\.lineIndex)
    }

    @Test func aLinearChainIsKeptWhole() {
        #expect(Self.lineIndices([("a", nil), ("b", "a"), ("c", "b"), ("d", "c")]) == [1, 2, 3, 4])
    }

    @Test func aBranchTheUserLeftIsLeftOut() {
        // b and c were abandoned when the user went back to a and continued with d.
        #expect(Self.lineIndices([("a", nil), ("b", "a"), ("c", "b"), ("d", "a"), ("e", "d")]) == [1, 4, 5])
    }

    @Test func aRepeatedIDMeansTheLaterEntry() {
        #expect(Self.lineIndices([("a", nil), ("x", "a"), ("b", nil), ("x", "b"), ("c", "x")]) == [3, 4, 5])
    }

    @Test func aMissingParentEndsTheChain() {
        #expect(Self.lineIndices([("a", nil), ("b", "gone"), ("c", "b")]) == [2, 3])
    }

    @Test func aLoopEndsOnceItComesBackAround() {
        #expect(Self.lineIndices([("a", "c"), ("b", "a"), ("c", "b")]) == [1, 2, 3])
        #expect(Self.lineIndices([("a", "a")]) == [1])
    }

    @Test func versionOneEntriesWithoutIDsAreAllKeptInFileOrder() {
        #expect(Self.lineIndices([(nil, nil), (nil, nil), (nil, nil)]) == [1, 2, 3])
        #expect(PiActiveBranch.entries(in: []).isEmpty)
    }

    @Test func entriesWithoutIDsAreLeftOutOnceAnyEntryHasOne() {
        #expect(Self.lineIndices([(nil, nil), ("a", nil), ("x", "a"), ("b", "a"), (nil, nil)]) == [2, 4])
    }
}
