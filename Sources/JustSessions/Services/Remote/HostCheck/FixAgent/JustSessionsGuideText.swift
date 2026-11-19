import Foundation

/// Reads `JustSessionsGuideSection`s out of the guides the app ships, so an agent reads the guides of the version
/// that checked the host.
enum JustSessionsGuideText {
    /// The guides are at the top level of the app's resource bundle; see `Package.swift`.
    static var shippedGuidesDirectory: URL? {
        AppLocalization.resourceBundle.resourceURL
    }

    /// The section's text from its heading line up to the next heading of the same or a higher level; nil when the
    /// guide or the heading is missing.
    static func text(of section: JustSessionsGuideSection, in guidesDirectory: URL? = shippedGuidesDirectory) -> String? {
        guard let guideURL = guidesDirectory?.appendingPathComponent(section.fileName),
            let markdown = try? String(contentsOf: guideURL, encoding: .utf8)
        else { return nil }
        return self.section(headed: section.heading, in: markdown)
    }

    static func section(headed heading: String, in markdown: String) -> String? {
        let lines = markdown.components(separatedBy: "\n")
        var isInCodeBlock = false
        var sectionStart: (index: Int, level: Int)?
        var sectionEnd = lines.endIndex
        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { isInCodeBlock.toggle() }
            guard !isInCodeBlock, let (level, lineHeading) = headingParts(of: line) else { continue }
            if let sectionStart {
                if level <= sectionStart.level {
                    sectionEnd = index
                    break
                }
            } else if lineHeading == heading {
                sectionStart = (index, level)
            }
        }
        guard let sectionStart else { return nil }
        return lines[sectionStart.index..<sectionEnd].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The git tag of a release build's guides, `v1.2.11`, or `main` for a development build, whose version has more
    /// than the release's three numbers.
    static func gitReference(forAppVersion appVersion: String) -> String {
        let numbers = appVersion.split(separator: ".", omittingEmptySubsequences: false)
        let isReleaseVersion = numbers.count == 3 && numbers.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }
        return isReleaseVersion ? "v\(appVersion)" : "main"
    }

    private static func headingParts(of line: String) -> (level: Int, heading: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, line.dropFirst(level + 1).trimmingCharacters(in: .whitespaces))
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
