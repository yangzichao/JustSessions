import Foundation
import Testing

/// The system's `.secondary` and `.tertiary` text is 3.0 and 1.7 on the light themes' surfaces, and its red falls short
/// too. Views use the theme's text colors in `ThemePalette` instead, which are readable on every surface.
struct ThemeTextColorContractTests {
    @Test func viewsDrawTextInTheThemesReadableColors() throws {
        let viewsDirectory = RepositoryFiles.rootDirectory.appendingPathComponent("Sources/JustSessions/Views")
        let files = try #require(FileManager.default.enumerator(at: viewsDirectory, includingPropertiesForKeys: nil))
        let systemTextStyle = try Regex(#"(foregroundStyle|foregroundColor)\([^)]*\.(secondary|tertiary|quaternary|red|orange|gray)\b"#)
        var offendingLines: [String] = []
        for case let file as URL in files where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() where line.contains(systemTextStyle) {
                offendingLines.append("\(file.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(offendingLines.isEmpty, "\(offendingLines.joined(separator: "\n"))")
    }
}
