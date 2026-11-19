import Foundation

@MainActor
protocol SessionNotifying: AnyObject {
    var isApplicationActive: Bool { get }
    func notify(_ notification: SessionNotification)
}
