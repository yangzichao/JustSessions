import Foundation
import Testing
@testable import JustSessions

struct AppLocalizationTests {
    @Test(arguments: [(["zh-CN"], "zh-Hans"), (["zh-TW"], "zh-Hans"), (["en-GB"], "en"), (["fr-FR", "zh-CN"], "zh-Hans"), (["fr-FR"], "en")])
    func matchesSystemPreferencesAndFallsBackToEnglish(input: ([String], String)) {
        #expect(AppInterfaceLanguage.followSystem.localizationIdentifier(
            availableLocalizations: ["en", "zh-Hans"], preferredLanguages: input.0
        ) == input.1)
    }

    @Test func explicitSelectionOverridesSystemAndMissingResourcesFallBack() {
        let english = AppInterfaceLanguage(identifier: "en")
        let chinese = AppInterfaceLanguage(identifier: "zh-Hans")
        #expect(AppLocalization.string("General", language: chinese, preferredLanguages: ["en-US"]) == "通用")
        #expect(AppLocalization.string("General", language: english, preferredLanguages: ["zh-CN"]) == "General")
        #expect(AppLocalization.string("Untranslated source text", language: chinese) == "Untranslated source text")
        #expect(AppLocalization.string("General", language: AppInterfaceLanguage(identifier: "removed-language"), preferredLanguages: ["zh-CN"]) == "通用")
    }

    @Test func preservesInterpolatedValuesAndNeverTranslatesUserContent() {
        let chinese = AppInterfaceLanguage(identifier: "zh-Hans")
        let tabNumber = 7
        #expect(AppLocalization.string("Tab \(tabNumber)", language: chinese) == "标签 7")
        let projectName = "Settings"
        #expect(AppLocalization.string("New session in \(projectName)", language: chinese) == "在 Settings 中新建会话")
    }

    @Test func deduplicatesResourcesAndDoesNotExposeBaseAsALanguage() {
        let choices = AppInterfaceLanguage.choices(availableLocalizations: ["Base", "en", "ja", "en", ""])
        #expect(choices.map(\.id) == ["followSystem", "en", "ja"])
    }

    @Test func explicitResourcesPreserveStableKeysCustomTablesAndInterpolatedDefaults() throws {
        let fixture = try LocalizationBundleFixture()
        defer { fixture.remove() }
        let japanese = AppInterfaceLanguage(identifier: "ja")
        let title = LocalizedStringResource("settings.title", defaultValue: "General settings", table: "Settings",
                                            bundle: .atURL(fixture.bundle.bundleURL))
        #expect(AppLocalization.string(resource: title, language: japanese) == "一般設定")
        let projectName = "Settings"
        let project = LocalizedStringResource("settings.project", defaultValue: "Settings for \(projectName)", table: "Settings",
                                              bundle: .atURL(fixture.bundle.bundleURL))
        #expect(AppLocalization.string(resource: project, language: japanese) == "Settings の設定")
        let missing = LocalizedStringResource("missing.key", defaultValue: "Source for \(projectName)", table: "Settings",
                                              bundle: .atURL(fixture.bundle.bundleURL))
        #expect(AppLocalization.string(resource: missing, language: japanese) == "Source for Settings")
    }

    @Test func canonicalizesSwiftPMResourceNamesAndDevelopmentLanguage() {
        let choices = AppInterfaceLanguage.choices(availableLocalizations: ["en", "zh-hans", "zh-Hans"])
        #expect(choices.map(\.id) == ["followSystem", "en", "zh-Hans"])
        #expect(AppInterfaceLanguage.followSystem.localizationIdentifier(
            availableLocalizations: ["en", "zh-hans"], preferredLanguages: ["fr"], developmentLocalization: "zh-hans"
        ) == "zh-Hans")
    }

    @Test func respectsDistinctScriptsWhenBothAreTranslated() {
        #expect(AppInterfaceLanguage.followSystem.localizationIdentifier(
            availableLocalizations: ["en", "zh-Hans", "zh-Hant"], preferredLanguages: ["zh-TW"]
        ) == "zh-Hant")
        #expect(AppInterfaceLanguage.followSystem.localizationIdentifier(
            availableLocalizations: ["en", "zh-Hans", "zh-Hant"], preferredLanguages: ["zh-CN"]
        ) == "zh-Hans")
    }

    @Test(arguments: [0, 1, 2])
    func packagedPluralRulesUseEachLanguagesGrammar(count: Int) {
        #expect(AppLocalization.string("Copy \(count) conversations", language: AppInterfaceLanguage(identifier: "en"))
            == (count == 1 ? "Copy 1 conversation" : "Copy \(count) conversations"))
        #expect(AppLocalization.string("Copy \(count) conversations", language: AppInterfaceLanguage(identifier: "zh-Hans"))
            == "复制 \(count) 个对话")
    }
}
