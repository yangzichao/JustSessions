import Foundation
import Testing

/// A third language supplied solely by resource files, like a future translation contribution.
struct LocalizationBundleFixture {
    let directory: URL
    let bundle: Bundle

    init(localizations: [String] = ["en", "ja"]) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "dev.justsessions.tests.localization.\(UUID().uuidString)",
                                   "CFBundleDevelopmentRegion": "en", "CFBundleLocalizations": localizations]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: directory.appendingPathComponent("Info.plist"))
        for (language, value) in [("en", "General"), ("ja", "一般")] {
            guard localizations.contains(language) else { continue }
            let localizationDirectory = directory.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: localizationDirectory, withIntermediateDirectories: true)
            try "\"General\" = \"\(value)\";\n".write(to: localizationDirectory.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
            let customStrings = language == "ja"
                ? "\"settings.title\" = \"一般設定\";\n\"settings.project\" = \"%@ の設定\";\n"
                : "\"settings.title\" = \"General settings\";\n\"settings.project\" = \"Settings for %@\";\n"
            try customStrings.write(to: localizationDirectory.appendingPathComponent("Settings.strings"), atomically: true, encoding: .utf8)
        }
        bundle = try #require(Bundle(url: directory))
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}
