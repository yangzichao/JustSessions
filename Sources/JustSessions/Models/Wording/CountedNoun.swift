import Foundation

enum CountedNoun {
    static func phrase(count: Int, singular: String, plural: String? = nil) -> String {
        "\(count) \(count == 1 ? singular : plural ?? singular + "s")"
    }
}
