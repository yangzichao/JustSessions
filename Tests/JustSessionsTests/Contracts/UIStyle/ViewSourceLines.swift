import Foundation
import Testing

/// The lines of the app's view code, for the contract tests that hold views to docs/development/ui-style.md.
struct ViewSourceLines {
    struct Line {
        /// The file's path under `Sources/JustSessions/Views/`, such as `Theme/Colors/ThemePalette.swift`.
        let path: String
        let number: Int
        let text: Substring

        var description: String {
            "Views/\(path):\(number): \(text.trimmingCharacters(in: .whitespaces))"
        }
    }

    /// Where the style's own values are defined, which every rule lets set them.
    static let themeFolder = "Theme/"
    /// Miniature drawings, which scale the window down rather than follow the spec: the theme thumbnails in Settings
    /// and the app mark.
    static let drawingFolders = ["Settings/Appearance/App/Sketch/", "Branding/"]

    let files: [(path: String, lines: [Substring])]

    init() throws {
        let viewsDirectory = RepositoryFiles.rootDirectory.appendingPathComponent("Sources/JustSessions/Views")
        let enumerator = try #require(FileManager.default.enumerator(at: viewsDirectory, includingPropertiesForKeys: nil))
        var files: [(String, [Substring])] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let path = String(file.path.dropFirst(viewsDirectory.path.count + 1))
            let source = try String(contentsOf: file, encoding: .utf8)
            files.append((path, source.split(separator: "\n", omittingEmptySubsequences: false)))
        }
        self.files = files.sorted { $0.0 < $1.0 }
    }

    /// Lines matching `pattern` outside the theme's own folder and the drawings.
    func lines(matching pattern: Regex<AnyRegexOutput>) -> [String] {
        let exemptFolders = [Self.themeFolder] + Self.drawingFolders
        return
            files
            .filter { file in !exemptFolders.contains { file.path.hasPrefix($0) } }
            .flatMap { file in
                file.lines.enumerated()
                    .filter { _, text in text.contains(pattern) }
                    .map { index, text in Line(path: file.path, number: index + 1, text: text).description }
            }
    }
}
