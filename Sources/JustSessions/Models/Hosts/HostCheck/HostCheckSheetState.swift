import Foundation

struct HostCheckSheetState: Identifiable, Equatable, Sendable {
    let id = UUID()
    let host: String
    let session: HostCheckSession?
    var runID = UUID()
    var report: HostCheckReport?
    var step = HostCheckStep.logIn
    var stepStartedAt = Date.now

    var isChecking: Bool { report == nil }
}
