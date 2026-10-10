import AppKit
import Testing
@testable import JustSessions

/// About JustSessions opens one window, titled in the app's language, with the version and LICENSE's copyright.
@MainActor
struct AboutWindowTests {
    @Test func versionShowsTheBuildNumberOnlyWhenItDiffers() {
        #expect(AboutAppDetails.version(shortVersion: "1.2.0", buildNumber: "120") == "1.2.0 (120)")
        #expect(AboutAppDetails.version(shortVersion: "1.2.0", buildNumber: "1.2.0") == "1.2.0")
        #expect(AboutAppDetails.version(shortVersion: "1.2.0", buildNumber: nil) == "1.2.0")
    }

    @Test func aBuildWithoutAVersionIsADevelopmentBuild() {
        #expect(AboutAppDetails.version(shortVersion: nil, buildNumber: "120") == nil)
        #expect(AboutAppDetails.version(shortVersion: "", buildNumber: nil) == nil)
    }

    @Test func copyrightAndLicenseMatchTheLicenseFile() throws {
        let license = try RepositoryFiles.contents(of: "LICENSE")
        #expect(license.hasPrefix("MIT License"))
        #expect(license.contains("Copyright (c) \(AboutAppDetails.copyrightYear) \(AboutAppDetails.copyrightHolder)"))
        #expect(AboutAppDetails.copyrightNotice == "© 2026 Zichao Yang")
        #expect(AppLinks.licenseURL.absoluteString == "https://github.com/yangzichao/JustSessions/blob/main/LICENSE")
    }

    @Test func showingAgainBringsTheSameWindowForwardInTheAppLanguage() throws {
        _ = NSApplication.shared
        let controller = AboutWindowController.shared
        controller.show(language: AppInterfaceLanguage(identifier: "zh-Hans"))
        let window = try #require(controller.window)
        defer { window.close() }
        #expect(window.isVisible)
        #expect(window.title == "关于 JustSessions")
        #expect(window.isExcludedFromWindowsMenu)

        controller.show(language: AppInterfaceLanguage(identifier: "en"))

        #expect(controller.window === window)
        #expect(window.title == "About JustSessions")
    }
}
