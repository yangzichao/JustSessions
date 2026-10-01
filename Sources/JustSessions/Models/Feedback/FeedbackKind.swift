import Foundation

enum FeedbackKind: String, CaseIterable, Identifiable {
    case bug = "Bug report"
    case feature = "Feature request"
    case other = "Other feedback"

    var id: String { rawValue }

    var titlePrefix: String {
        switch self {
        case .bug: "Bug"
        case .feature: "Feature"
        case .other: "Feedback"
        }
    }

    var guidance: String {
        switch self {
        case .bug: "What happened? Include the steps to reproduce it, what you expected, and what happened instead."
        case .feature: "What would you like to do? Describe the problem and how the suggested feature would help."
        case .other: "What is working well, or what could be better?"
        }
    }
}
