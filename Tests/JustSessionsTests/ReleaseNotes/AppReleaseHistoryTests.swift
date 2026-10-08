import Foundation
import Testing
@testable import JustSessions

struct AppReleaseHistoryTests {
    @Test func historyLoadsFromARelocatedPackagedBundleWithoutBuildResources() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let copiedBundleURL = temporaryDirectory.appendingPathComponent("JustSessions_JustSessions.bundle")
        try FileManager.default.copyItem(at: AppLocalization.resourceBundle.bundleURL, to: copiedBundleURL)
        let packagedBundle = try #require(Bundle(url: copiedBundleURL))
        let releases = try AppReleaseHistory.load(from: packagedBundle)
        let originalReleases = try AppReleaseHistory.bundled.get()
        #expect(releases.map(\.version) == originalReleases.map(\.version))
    }

    @Test func packagedCatalogLoadsAndIncludesBothLanguages() throws {
        let releases = try AppReleaseHistory.bundled.get()
        #expect(!releases.isEmpty)
        #expect(Set(releases.map(\.version)).count == releases.count)
        for release in releases {
            #expect(!release.title.localized(for: Locale(identifier: "en")).isEmpty)
            #expect(!release.title.localized(for: Locale(identifier: "zh-Hans")).isEmpty)
            #expect(!release.sections.isEmpty)
            #expect(release.sections.allSatisfy { !$0.items.isEmpty })
        }
    }

    @Test func editorialCopyUsesTheChosenLanguageAndFallsBackToEnglish() throws {
        let release = try #require(AppReleaseHistory.bundled.get().first)
        #expect(release.title.localized(for: Locale(identifier: "zh-Hans")) == release.title.simplifiedChinese)
        #expect(release.title.localized(for: Locale(identifier: "en_US")) == release.title.english)
        #expect(release.title.localized(for: Locale(identifier: "ja")) == release.title.english)
    }

    @Test func releaseDatesRenderAsCalendarDaysInTheChosenLocale() throws {
        let catalogEntry = try #require(AppReleaseHistory.bundled.get().first)
        let release = AppReleaseNotes(
            version: "1.0.9", publishedOn: "2026-10-08", title: catalogEntry.title, sections: catalogEntry.sections
        )
        #expect(release.formattedDate(locale: Locale(identifier: "en_US")) == "Oct 8, 2026")
        #expect(release.formattedDate(locale: Locale(identifier: "zh-Hans")) == "2026年10月8日")
    }
}
