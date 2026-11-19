import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct TranscriptTextViewTests {
    /// AppKit's `init(frame:)` calls `init(frame:textContainer:)` on the subclass; without an override of it, creating
    /// the view that highlights a match stopped the app.
    @Test func setsUpItsTextSystem() {
        let view = TranscriptTextView()
        view.textStorage?.setAttributedString(NSAttributedString(string: "Find me"))

        #expect(view.string == "Find me")
        #expect(view.measuredSize(width: 200).height > 0)
    }

    @Test func assemblesTextKitOne() throws {
        let view = TranscriptTextView()
        view.setContent(Self.content("Read me"))

        #expect(view.string == "Read me")
        #expect(!view.isEditable)
        #expect(view.isSelectable)
        #expect(view.layoutManager is TranscriptTextLayoutManager)
        #expect(view.textLayoutManager == nil)
    }

    @Test func measuresAtTheOfferedWidthOrOnOneLine() {
        let view = TranscriptTextView()
        view.setContent(Self.content(String(repeating: "word ", count: 60)))

        let unbounded = view.measuredSize(width: nil)
        let wrapped = view.measuredSize(width: 200)

        #expect(wrapped.width <= 200)
        #expect(wrapped.height > unbounded.height * 3)
        #expect(unbounded.width > 200)
    }

    @Test func shortTextKeepsItsOwnWidth() {
        let view = TranscriptTextView()
        view.setContent(Self.content("Value"))

        #expect(view.measuredSize(width: 260).width == view.measuredSize(width: nil).width)
        #expect(view.measuredSize(width: nil).width < 60)
    }

    @Test func laysOutAtThePlacedWidth() throws {
        let view = TranscriptTextView()
        view.setContent(Self.content(String(repeating: "word ", count: 60)))
        _ = view.measuredSize(width: 200)
        _ = view.measuredSize(width: nil)

        view.setFrameSize(NSSize(width: 200, height: view.measuredSize(width: 200).height))

        #expect(try #require(view.textContainer).size.width == 200)
    }

    /// Blocks are as tall as SwiftUI's text was before the reader drew text with AppKit: SwiftUI sets the system font's
    /// lines taller than TextKit at some sizes, such as 15 pt, and counts the empty line after code's final line break.
    @Test(arguments: [
        (TranscriptTextStyle(fontSize: 15), "One line"),
        (TranscriptTextStyle(fontSize: 15), "Two\nlines"),
        (TranscriptTextStyle(fontSize: 17), "Two\nlines"),
        (TranscriptTextStyle(fontSize: 10, lineSpacing: 0), "A note"),
        (TranscriptTextStyle(fontSize: 14, isMonospaced: true, lineSpacing: 3), "let x = 1\nlet y = 2\n"),
        (TranscriptTextStyle(fontSize: 15, isSemibold: true), "Header cell"),
    ])
    func linesAreAsTallAsSwiftUISetsThem(style: TranscriptTextStyle, text: String) {
        let view = TranscriptTextView()
        view.setContent(
            TranscriptTextContent(
                source: AttributedString(text), style: style,
                colors: TranscriptTextColors(theme: ResolvedAppTheme(.justSessions), isDark: false)
            ))
        let swiftUIText = NSHostingView(
            rootView: Text(text)
                .font(
                    .system(
                        size: style.fontSize, weight: style.isSemibold ? .semibold : .regular,
                        design: style.isMonospaced ? .monospaced : .default)
                )
                .lineSpacing(style.lineSpacing)
                .fixedSize())

        #expect(view.measuredSize(width: nil).height == swiftUIText.fittingSize.height)
    }

    static func content(_ text: String) -> TranscriptTextContent {
        TranscriptTextContent(
            source: AttributedString(text), style: TranscriptTextStyle(fontSize: 13),
            colors: TranscriptTextColors(theme: ResolvedAppTheme(.justSessions), isDark: false)
        )
    }
}
