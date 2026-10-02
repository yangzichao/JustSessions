import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingWidthLayoutTests {
    private let wideWindowWidth: CGFloat = 1600
    private let readingPadding: CGFloat = 24

    @Test func readableWidthKeepsAWideWindowsColumnCentered() async throws {
        let fixture = try TranscriptScrollViewFixture(width: wideWindowWidth)
        defer { fixture.close() }
        let scrollView = try await fixture.show(TranscriptScrollViewFixture.conversation("readable-width"),
                                                transcript: TranscriptScrollViewFixture.transcript(count: 4))
        let visibleWidth = scrollView.contentView.bounds.width
        #expect(visibleWidth > TranscriptReadingWidth.readableColumnWidth + 2 * readingPadding)

        let entryFrames = fixture.visibleEntryFrames(in: scrollView)
        #expect(!entryFrames.isEmpty)
        for frame in entryFrames {
            #expect(abs(frame.width - TranscriptReadingWidth.readableColumnWidth) < 1)
            #expect(abs(frame.midX - visibleWidth / 2) < 1)
        }
    }

    @Test func fullWidthSpansTheWindowAndAnOpenTranscriptFollowsTheSetting() async throws {
        let fixture = try TranscriptScrollViewFixture(width: wideWindowWidth)
        defer { fixture.close() }
        fixture.settings.userDefaults.set(TranscriptReadingWidth.full.rawValue, forKey: TranscriptReadingWidth.userDefaultsKey)
        let scrollView = try await fixture.show(TranscriptScrollViewFixture.conversation("full-width"),
                                                transcript: TranscriptScrollViewFixture.transcript(count: 4))
        let visibleWidth = scrollView.contentView.bounds.width

        let fullFrames = fixture.visibleEntryFrames(in: scrollView)
        #expect(!fullFrames.isEmpty)
        for frame in fullFrames {
            #expect(abs(frame.width - (visibleWidth - 2 * readingPadding)) < 1)
            #expect(abs(frame.minX - readingPadding) < 1)
        }

        fixture.settings.userDefaults.set(TranscriptReadingWidth.readable.rawValue, forKey: TranscriptReadingWidth.userDefaultsKey)
        try await fixture.settleLayout()
        let readableFrames = fixture.visibleEntryFrames(in: scrollView)
        #expect(!readableFrames.isEmpty)
        for frame in readableFrames {
            #expect(abs(frame.width - TranscriptReadingWidth.readableColumnWidth) < 1)
        }
    }
}
