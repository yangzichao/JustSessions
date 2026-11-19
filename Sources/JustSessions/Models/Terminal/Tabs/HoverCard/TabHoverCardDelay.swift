import CoreGraphics
import Foundation

@MainActor
enum TabHoverCardDelay {
    static let atNarrowestTabs: Duration = .milliseconds(300)
    static let atWidestNarrowedTabs: Duration = .milliseconds(800)
    static let extraAtFullWidth: Duration = .milliseconds(500)

    static func beforeShowing(tabWidth: CGFloat) -> Duration {
        let narrowest = Double(WorkspaceTabMetrics.minimumWidth)
        let widest = Double(WorkspaceTabMetrics.maximumWidth)
        let width = Double(tabWidth)
        guard width > narrowest else { return atNarrowestTabs }
        let logFraction = log(width - narrowest + 1) / log(widest - narrowest + 1)
        let delay = atNarrowestTabs + (atWidestNarrowedTabs - atNarrowestTabs) * logFraction
        return width >= widest ? delay + extraAtFullWidth : delay
    }
}
