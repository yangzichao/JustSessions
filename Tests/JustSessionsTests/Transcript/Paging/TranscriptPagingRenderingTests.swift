import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct TranscriptPagingRenderingTests {
    @Test func pagedReadersRenderAtBothWidthsInEveryThemeAndAppearance() async throws {
        let files = try TranscriptPagingFixture(count: 500, lineCount: 3)
        defer { files.remove() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: .entry(index: TranscriptPageIdentity.entryID(record: 200, part: 0), offset: -150))
        try await expectEventually { !model.isLoading }
        let transcript = try #require(model.transcript)
        for width in [400.0, 820.0] {
            for scheme in [ColorScheme.light, .dark] {
                let positions = TranscriptReadingPositionStore()
                positions.record(model.restorationPosition, for: files.conversation.id)
                let content = TranscriptScrollView(conversation: files.conversation, transcript: transcript,
                                                   positionStore: positions, paging: model)
                    .background(ThemePalette.contentSurface)
                    .appTheme(from: themeStore)
                    .defaultAppStorage(settings.userDefaults)
                let fixture = ThemeSurfaceRenderingFixture(content: AnyView(content), size: CGSize(width: width, height: 600), colorScheme: scheme)
                defer { fixture.close() }
                for theme in AppTheme.allCases {
                    themeStore.setTheme(theme)
                    let bitmap = try await fixture.capture(named: "paged-reader-\(Int(width))-\(theme.rawValue)-\(scheme)")
                    #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
                }
            }
        }
    }
}
