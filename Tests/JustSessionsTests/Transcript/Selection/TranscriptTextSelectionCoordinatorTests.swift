import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptTextSelectionCoordinatorTests {
    @Test
    func registersEveryTextBlockInReadingOrder() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }

        #expect(
            try fixture.coordinator.orderedViews.map(\.view.string) == [
                TranscriptTextSelectionFixture.question, "Intro paragraph.", "First item", "Second item",
                "A", "B", "1", "2", "let x = 1\n", TranscriptTextSelectionFixture.lastReply,
            ])
    }

    @Test(arguments: [false, true])
    func dragSelectsAcrossBlocksAndMessages(isDraggedUpward: Bool) async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        let question = try #require(blocks.first)
        let lastReply = try #require(blocks.last)
        let start = try fixture.point(in: question, atCharacter: 4)
        let end = try fixture.point(in: lastReply, atCharacter: 4)

        if isDraggedUpward {
            try fixture.drag(from: end, to: start, in: lastReply)
        } else {
            try fixture.drag(from: start, to: end, in: question)
        }

        #expect(
            fixture.selectedTexts == [
                "does the sidebar redraw?", "Intro paragraph.", "First item", "Second item",
                "A", "B", "1", "2", "let x = 1\n", "Last",
            ])
        #expect(
            try fixture.coordinator.copiedText() == """
                does the sidebar redraw?

                Intro paragraph.

                • First item
                • Second item

                A\tB
                1\t2

                let x = 1

                Last
                """)
        #expect(try fixture.coordinator.isTracking == false)
    }

    @Test
    func clickClearsAndShiftClickExtends() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        let question = blocks[0]
        let intro = blocks[1]

        try fixture.drag(from: fixture.point(in: question, atCharacter: 0), to: fixture.point(in: question, atCharacter: 3), in: question)
        #expect(fixture.selectedTexts == ["Why"])

        try fixture.click(at: fixture.point(in: intro, atCharacter: 5), in: intro, modifiers: .shift)
        #expect(fixture.selectedTexts == [TranscriptTextSelectionFixture.question, "Intro"])

        try fixture.click(at: fixture.point(in: intro, atCharacter: 2), in: intro)
        #expect(fixture.selectedTexts.isEmpty)
    }

    @Test
    func dragIntoTheGapBetweenBlocksSelectsToTheBlockBelow() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        let question = blocks[0]
        let intro = blocks[1]
        let questionFrame = question.convert(question.bounds, to: nil)
        let introFrame = intro.convert(intro.bounds, to: nil)
        // Window coordinates rise upward: the gap lies between the question's bottom and the intro's top.
        try #require(introFrame.maxY < questionFrame.minY)
        let gap = NSPoint(x: introFrame.midX, y: (introFrame.maxY + questionFrame.minY) / 2)

        try fixture.drag(from: fixture.point(in: question, atCharacter: 13), to: gap, in: question)

        #expect(fixture.selectedTexts == ["sidebar redraw?"])
        #expect(intro.selectedRange() == NSRange(location: 0, length: 0))
    }

    @Test
    func selectAllSelectsEveryLoadedBlock() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)

        blocks[3].selectAll(nil)

        #expect(fixture.selectedTexts == blocks.map(\.string))
    }

    /// A double or triple click is left to the text view, which selects a word or a line inside its block; the reader
    /// then takes that as its selection, clearing the other blocks.
    @Test
    func selectionInsideOneBlockReplacesASelectionAcrossBlocks() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let coordinator = try fixture.coordinator
        let blocks = coordinator.orderedViews.map(\.view)
        let question = blocks[0]
        try fixture.drag(from: fixture.point(in: question, atCharacter: 0), to: fixture.point(in: blocks[1], atCharacter: 5), in: question)
        let doubleClick = try fixture.mouseEvent(
            .leftMouseDown, at: fixture.point(in: question, atCharacter: 14), modifiers: [], clickCount: 2)
        #expect(coordinator.trackSelection(startingWith: doubleClick, in: question) == false)

        question.setSelectedRange(NSRange(location: 13, length: 7))
        coordinator.adoptSelection(of: question)

        #expect(fixture.selectedTexts == ["sidebar"])
        #expect(coordinator.copiedText() == nil)
    }

    @Test
    func escapeClearsTheSelection() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        blocks[0].selectAll(nil)

        blocks[0].cancelOperation(nil)

        #expect(fixture.selectedTexts.isEmpty)
    }

    @Test
    func copyWritesASelectionAcrossBlocksToThePasteboard() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        let lastReply = try #require(blocks.last)
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        #expect(lastReply.validateMenuItem(copyItem) == false)

        try fixture.drag(
            from: fixture.point(in: blocks[8], atCharacter: 4), to: fixture.point(in: lastReply, atCharacter: 4), in: blocks[8])
        // A block that only holds the end of the selection still enables Copy for it.
        #expect(lastReply.validateMenuItem(copyItem))
        lastReply.copy(nil)

        #expect(fixture.pasteboard.string(forType: .string) == "x = 1\n\nLast")
    }

    @Test
    func replacedBlockTakesBackItsPartOfTheSelection() async throws {
        let fixture = try await TranscriptTextSelectionFixture()
        defer { fixture.close() }
        let coordinator = try fixture.coordinator
        let (key, intro) = try coordinator.orderedViews[1]
        coordinator.selectAll()

        // SwiftUI recreates a block's view as it scrolls back into the loaded range: the new view joins the window as
        // the old one leaves it.
        intro.removeFromSuperview()
        let replacement = TranscriptTextView()
        replacement.setSelection(coordinator: coordinator, key: key, copyRole: .paragraph)
        replacement.setContent(TranscriptTextViewTests.content("Intro paragraph."))
        fixture.hostingView.addSubview(replacement)

        #expect(coordinator.view(for: key) === replacement)
        #expect(replacement.selectedRange() == NSRange(location: 0, length: 16))
    }

    /// AppKit draws only the first responder's selection in the accent, and every other block's in gray; the reader's
    /// blocks all draw it as the first responder does while one of them is focused.
    @Test
    func drawsTheSelectionInEveryBlockAsTheFocusedBlockDoes() async throws {
        let fixture = try await TranscriptTextSelectionFixture(isKeyWindow: true)
        defer { fixture.close() }
        let blocks = try fixture.coordinator.orderedViews.map(\.view)
        let question = blocks[0]
        let lastReply = try #require(blocks.last)
        try fixture.drag(from: fixture.point(in: question, atCharacter: 0), to: fixture.point(in: lastReply, atCharacter: 10), in: question)
        #expect(fixture.window.firstResponder === question)
        #expect(lastReply.drawsSelectionEmphasized)

        let focusedColor = try Self.colorBehindFirstSpace(in: question)
        let emphasizedColor = try Self.colorBehindFirstSpace(in: lastReply)
        fixture.window.makeFirstResponder(nil)
        let unfocusedColor = try Self.colorBehindFirstSpace(in: lastReply)

        #expect(lastReply.drawsSelectionEmphasized == false)
        #expect(emphasizedColor.isClose(to: focusedColor))
        #expect(!unfocusedColor.isClose(to: focusedColor))
    }

    /// The color drawn behind the first space in `view`, which shows the selection's background and no text.
    private static func colorBehindFirstSpace(in view: TranscriptTextView) throws -> NSColor {
        let offset = (view.string as NSString).range(of: " ").location
        try #require(offset != NSNotFound)
        let layoutManager = try #require(view.layoutManager)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: offset, length: 1), actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: try #require(view.textContainer))
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        // Text views are flipped, as bitmap rows are.
        return try #require(rep.colorAt(x: Int(rect.midX * scale), y: Int(rect.midY * scale))?.usingColorSpace(.sRGB))
    }
}

extension NSColor {
    fileprivate func isClose(to other: NSColor) -> Bool {
        abs(redComponent - other.redComponent) < 0.02 && abs(greenComponent - other.greenComponent) < 0.02
            && abs(blueComponent - other.blueComponent) < 0.02
    }
}
