import Foundation

enum SSHLoginAnswer: Equatable, Sendable {
    case answered(String)
    case cancelledByUser
    case withdrawnBySSH

    init(asked answer: String?, questionWasWithdrawn: Bool) {
        if let answer {
            self = .answered(answer)
        } else {
            self = questionWasWithdrawn ? .withdrawnBySSH : .cancelledByUser
        }
    }

    var textForSSH: String? {
        guard case .answered(let text) = self else { return nil }
        return text
    }
}
