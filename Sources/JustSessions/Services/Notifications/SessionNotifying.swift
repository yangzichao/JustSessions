import Foundation

/// Where the store sends notifications about sessions that want you back. `SessionNotificationCenter` posts them
/// through macOS; tests record them.
@MainActor
protocol SessionNotifying: AnyObject {
    /// Whether the app is in front, where the selected tab is already in view.
    var isApplicationActive: Bool { get }
    func notify(_ notification: SessionNotification)
}
