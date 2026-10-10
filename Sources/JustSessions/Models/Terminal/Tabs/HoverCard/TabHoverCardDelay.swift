import CoreGraphics
import Foundation

/// How long the pointer rests on a tab or group label before the first hover card shows, worked out as Chrome's
/// `GetShowDelay` does: 300 ms while tabs are at their narrowest, their titles cut the most, rising on a log scale to
/// 800 ms as tabs widen to their full width, and 500 ms more at full width, where a tab already shows most of its
/// title.
enum TabHoverCardDelay {
    static let atNarrowestTabs: Duration = .milliseconds(300)
    static let atWidestNarrowedTabs: Duration = .milliseconds(800)
    /// Chrome's `kTabHoverCardAdditionalMaxWidthDelay`.
    static let extraAtFullWidth: Duration = .milliseconds(500)

    /// - Parameter tabWidth: the width the bar's tabs share; a split's tabs are half of it.
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
