import Foundation

/// A count with its noun in the matching form, such as "1 session" or "3 sessions".
enum CountedNoun {
    static func phrase(count: Int, singular: String, plural: String? = nil) -> String {
        "\(count) \(count == 1 ? singular : plural ?? singular + "s")"
    }
}
