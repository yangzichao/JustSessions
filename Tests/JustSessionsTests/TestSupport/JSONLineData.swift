import Foundation

/// Each string as one line of a JSON Lines file, the way the readers get lines from a session file.
func jsonLines(_ lines: [String]) -> [Data] {
    lines.map { Data($0.utf8) }
}
