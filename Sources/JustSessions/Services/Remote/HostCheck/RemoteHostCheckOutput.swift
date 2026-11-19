import Foundation

struct RemoteHostCheckOutput: Equatable, Sendable {
    private(set) var textsByKey: [String: String] = [:]

    init(_ output: String) {
        let markerPrefix = RemoteHostCheckScript.marker + " "
        var key: String?
        var linesByKey: [String: [String]] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(markerPrefix) {
                let newKey = String(line.dropFirst(markerPrefix.count)).trimmingCharacters(in: .whitespaces)
                key = newKey
                linesByKey[newKey] = []
            } else if let key {
                linesByKey[key, default: []].append(String(line))
            }
        }
        textsByKey = linesByKey.mapValues {
            $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var reachedLoginShell: Bool { textsByKey["shell"] != nil }

    func text(_ key: String) -> String? {
        guard let text = textsByKey[key], !text.isEmpty else { return nil }
        return text
    }

    func exitStatus(_ key: String) -> Int32? {
        text(key).flatMap { Int32($0) }
    }
}
