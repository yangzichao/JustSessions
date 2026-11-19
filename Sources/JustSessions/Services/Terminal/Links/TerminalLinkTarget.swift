import Foundation

/// What a link in a tab points at. Both engines hand over the same text: an OSC 8 hyperlink's target, or the URL or
/// path they found under the pointer, such as `https://github.com`, `Sources/App/main.swift:42`, or `~/notes.md`.
enum TerminalLinkTarget: Equatable {
    /// A web page or an email address, which opens as given in a tab on any host.
    case webAddress(URL)
    /// A file or folder on this Mac.
    case localItem(TerminalLinkLocalItem)
    /// A path in a tab on an SSH host, as printed, without a trailing line and column. The file is on the host, so
    /// nothing on this Mac opens it.
    case remotePath(String)

    /// Nil for a link that points at nothing the app can act on:
    /// - a URL with a scheme other than `http`, `https`, `mailto`, or `file`, since other schemes start apps that act
    ///   on what the program printed, unless it names a file, as `README.md:3` does;
    /// - a path to a file or folder that doesn't exist on this Mac.
    ///
    /// A relative path is in `workingDirectory`, the tab's project folder, where its CLI runs. A path that doesn't
    /// exist as printed is tried without a trailing line and column, as in `main.swift:42:7`. In a tab on an SSH host,
    /// any link without `://` that isn't a web address is taken as a path on the host, which this Mac can't check.
    init?(
        link: String,
        host: SessionHost,
        workingDirectory: String,
        homeDirectory: String = NSHomeDirectory(),
        localItemKind: (URL) -> TerminalLinkLocalItem.Kind? = TerminalLinkLocalItem.kind(of:)
    ) {
        let link = link.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty else { return nil }
        var path = link
        if let url = URL(string: link), let scheme = url.scheme?.lowercased() {
            if Self.schemesOpenedAsGiven.contains(scheme) {
                self = .webAddress(url)
                return
            }
            if scheme == "file" {
                path = url.path
            } else if link.contains("://") {
                return nil
            }
            // Any other "scheme" may be a file's name, as `README.md` is in `README.md:3`, so the link is tried as a
            // path.
        }
        guard host == .thisMac else {
            self = .remotePath(Self.splittingLineAndColumn(from: path).path)
            return
        }
        let absolutePath = Self.absolutePath(path, workingDirectory: workingDirectory, homeDirectory: homeDirectory)
        let candidates = [(path: absolutePath, lineNumber: nil, columnNumber: nil), Self.splittingLineAndColumn(from: absolutePath)]
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.path)
            if let kind = localItemKind(url) {
                self = .localItem(
                    TerminalLinkLocalItem(
                        url: url, kind: kind, lineNumber: candidate.lineNumber, columnNumber: candidate.columnNumber
                    ))
                return
            }
        }
        return nil
    }

    private static let schemesOpenedAsGiven: Set<String> = ["http", "https", "mailto"]

    private static func absolutePath(_ path: String, workingDirectory: String, homeDirectory: String) -> String {
        let expandedPath: String
        if path == "~" {
            expandedPath = homeDirectory
        } else if path.hasPrefix("~/") {
            expandedPath = (homeDirectory as NSString).appendingPathComponent(String(path.dropFirst(2)))
        } else if path.hasPrefix("/") {
            expandedPath = path
        } else {
            expandedPath = (workingDirectory as NSString).appendingPathComponent(path)
        }
        // Removes `.` and `..` only. `NSString.standardizingPath` would also drop a `/private` it finds a way around.
        return URL(fileURLWithPath: expandedPath).standardizedFileURL.path
    }

    /// `main.swift:42` becomes `main.swift` and line 42, and `main.swift:42:7` adds column 7; any other path stays as
    /// it is.
    private static func splittingLineAndColumn(from path: String) -> (path: String, lineNumber: Int?, columnNumber: Int?) {
        guard let suffix = path.range(of: #"(:[0-9]+){1,2}$"#, options: .regularExpression) else { return (path, nil, nil) }
        let numbers = path[suffix].split(separator: ":").map { Int($0) }
        return (String(path[..<suffix.lowerBound]), numbers.first ?? nil, numbers.count > 1 ? numbers[1] : nil)
    }
}
