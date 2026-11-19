import Foundation

enum TerminalLinkTarget: Equatable {
    case webAddress(URL)
    case localItem(TerminalLinkLocalItem)
    case remotePath(String)

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

    private static func splittingLineAndColumn(from path: String) -> (path: String, lineNumber: Int?, columnNumber: Int?) {
        guard let suffix = path.range(of: #"(:[0-9]+){1,2}$"#, options: .regularExpression) else { return (path, nil, nil) }
        let numbers = path[suffix].split(separator: ":").map { Int($0) }
        return (String(path[..<suffix.lowerBound]), numbers.first ?? nil, numbers.count > 1 ? numbers[1] : nil)
    }
}
