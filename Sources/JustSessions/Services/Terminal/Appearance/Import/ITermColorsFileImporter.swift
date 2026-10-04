import Foundation

/// Copies the colors in an iTerm2 color preset file, such as the ones collected by iTerm2-Color-Schemes.
enum ITermColorsFileImporter {
    static func importFile(at url: URL) throws -> ImportedTerminalColors {
        guard let data = try? Data(contentsOf: url),
              let colors = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw TerminalColorsImportError.unreadableFile
        }
        // A preset holds one set of colors, or only a light and a dark set.
        let hasOnlyLightAndDarkColors = colors["Ansi 0 Color"] == nil
            && colors["Ansi 0 Color" + ITermColorsReader.lightSuffix] != nil
            && colors["Ansi 0 Color" + ITermColorsReader.darkSuffix] != nil
        return ImportedTerminalColors(
            sourceName: url.deletingPathExtension().lastPathComponent,
            variants: try ITermColorsReader.variants(from: colors, usesSeparateLightAndDarkColors: hasOnlyLightAndDarkColors)
        )
    }
}
