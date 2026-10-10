import Testing
@testable import JustSessions

struct PinnedOrderTests {
    @Test func aNewPinGoesLastAndPinningAgainKeepsItsPlace() {
        var order = PinnedOrder(["a", "b"])

        order.pin("c")
        order.pin("a")

        #expect(order.ids == ["a", "b", "c"])
        #expect(order.place(of: "c") == 2)
    }

    @Test func unpinningClosesTheGap() {
        var order = PinnedOrder(["a", "b", "c"])

        order.unpin("b")

        #expect(order.ids == ["a", "c"])
        #expect(!order.contains("b"))
        #expect(order.place(of: "c") == 1)
    }

    @Test func movingPutsAPinBesideItsNeighbor() {
        var order = PinnedOrder(["a", "b", "c", "d"])

        order.move("d", to: .before("b"))
        #expect(order.ids == ["a", "d", "b", "c"])

        order.move("a", to: .after("c"))
        #expect(order.ids == ["d", "b", "c", "a"])

        order.move("d", to: .last)
        #expect(order.ids == ["b", "c", "a", "d"])
    }

    @Test func movingWhatIsNotPinnedPinsIt() {
        var order = PinnedOrder(["a", "b"])

        order.move("new", to: .before("b"))

        #expect(order.ids == ["a", "new", "b"])
    }

    @Test func aNeighborThatIsNotPinnedPutsThePinLast() {
        var order = PinnedOrder(["a", "b"])

        order.move("a", to: .before("gone"))

        #expect(order.ids == ["b", "a"])
    }

    @Test func aRepeatedIDKeepsItsFirstPlace() {
        #expect(PinnedOrder(["a", "b", "a"]).ids == ["a", "b"])
    }
}
