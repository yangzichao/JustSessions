import Foundation

func jsonLines(_ lines: [String]) -> [Data] {
    lines.map { Data($0.utf8) }
}
