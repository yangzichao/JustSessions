import Testing
@testable import JustSessions

struct TranscriptReadingTextSizeTests {
    @Test func theSavedKeyAndTheToolbarsRangeStayTheSame() {
        #expect(TranscriptReadingTextSize.userDefaultsKey == "transcriptReadingTextSize")
        #expect(TranscriptReadingTextSize.range == 12...22)
        #expect(TranscriptReadingTextSize.defaultSize == 15)
    }

    @Test func zoomingStopsAtTheRangeEnds() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(22.0, forKey: TranscriptReadingTextSize.userDefaultsKey)
        TranscriptReadingTextSize.zoom(.zoomIn, in: settings.userDefaults)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 22)

        settings.userDefaults.set(12.0, forKey: TranscriptReadingTextSize.userDefaultsKey)
        TranscriptReadingTextSize.zoom(.zoomOut, in: settings.userDefaults)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 12)
    }

    @Test func aSavedSizeOutsideTheRangeReadsAsTheNearestOneInside() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(80.0, forKey: TranscriptReadingTextSize.userDefaultsKey)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 22)
        TranscriptReadingTextSize.zoom(.zoomOut, in: settings.userDefaults)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 21)

        settings.userDefaults.set("large", forKey: TranscriptReadingTextSize.userDefaultsKey)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 15)
        #expect(TranscriptReadingTextSize.clamped(.nan) == 15)
    }
}
