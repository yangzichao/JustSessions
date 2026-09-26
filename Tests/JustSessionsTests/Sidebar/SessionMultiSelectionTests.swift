import Testing
@testable import JustSessions

struct SessionMultiSelectionTests {
    private let orderedConversationIDs = ["a", "b", "c", "d", "e"]

    @Test func commandClickTogglesRowsIntoAndOutOfSelection() {
        var selection = SessionMultiSelection()
        selection.selectOnly("a")
        selection.toggle("c")
        #expect(selection.selectedConversationIDs == ["a", "c"])
        #expect(selection.hasMultipleSelected)

        selection.toggle("a")
        #expect(selection.selectedConversationIDs == ["c"])
        #expect(!selection.hasMultipleSelected)
    }

    @Test func shiftClickSelectsRangeFromAnchorInEitherDirection() {
        var selection = SessionMultiSelection()
        selection.selectOnly("b")
        selection.selectRange(to: "d", in: orderedConversationIDs)
        #expect(selection.selectedConversationIDs == ["b", "c", "d"])

        // A second Shift-click replaces the range but keeps the original anchor.
        selection.selectRange(to: "a", in: orderedConversationIDs)
        #expect(selection.selectedConversationIDs == ["a", "b"])
        #expect(selection.anchorConversationID == "b")
    }

    @Test func shiftClickWithoutVisibleAnchorSelectsOnlyClickedRow() {
        var selection = SessionMultiSelection()
        selection.selectRange(to: "c", in: orderedConversationIDs)
        #expect(selection.selectedConversationIDs == ["c"])

        selection.selectOnly("hidden")
        selection.selectRange(to: "e", in: orderedConversationIDs)
        #expect(selection.selectedConversationIDs == ["e"])
        #expect(selection.anchorConversationID == "e")
    }

    @Test func keepOnlyDropsRowsThatAreNoLongerVisible() {
        var selection = SessionMultiSelection()
        selection.selectOnly("a")
        selection.toggle("d")
        selection.keepOnly(["a", "b", "c"])
        #expect(selection.selectedConversationIDs == ["a"])
        #expect(selection.anchorConversationID == nil)
    }
}
