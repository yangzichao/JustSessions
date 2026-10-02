import Testing
@testable import JustSessions

struct TranscriptReadingWidthTests {
    @Test func readableWidthCapsTheColumnAndFullWidthDoesNot() {
        #expect(TranscriptReadingWidth.readable.maximumColumnWidth == 760)
        #expect(TranscriptReadingWidth.readable.maximumColumnWidth == TranscriptReadingWidth.readableColumnWidth)
        #expect(TranscriptReadingWidth.full.maximumColumnWidth == .infinity)
    }

    @Test func savedValuesStayTheSame() {
        #expect(TranscriptReadingWidth.userDefaultsKey == "transcriptReadingWidth")
        #expect(TranscriptReadingWidth.allCases.map(\.rawValue) == ["readable", "full"])
        #expect(TranscriptReadingWidth(rawValue: "readable") == .readable)
        #expect(TranscriptReadingWidth(rawValue: "full") == .full)
    }

    @Test func togglingSwitchesBetweenTheTwoWidths() {
        #expect(TranscriptReadingWidth.readable.toggled == .full)
        #expect(TranscriptReadingWidth.full.toggled == .readable)
    }
}
