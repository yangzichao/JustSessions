import Foundation

struct TerminalLinkLocalItem: Equatable {
    enum Kind: Equatable {
        case file
        case folder
    }

    let url: URL
    let kind: Kind
    var lineNumber: Int? = nil
    var columnNumber: Int? = nil

    static func kind(of url: URL) -> Kind? {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else { return nil }
        return values.isDirectory == true && values.isPackage != true ? .folder : .file
    }

    /// The path followed by the line and column, as VS Code's `--goto` takes it: `/path/main.swift:42:7`.
    var pathWithLineAndColumn: String {
        [url.path, lineNumber.map(String.init), columnNumber.map(String.init)].compactMap(\.self).joined(separator: ":")
    }
}
