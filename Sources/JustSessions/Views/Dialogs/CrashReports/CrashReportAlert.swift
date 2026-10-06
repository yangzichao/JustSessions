import AppKit

/// Asks whether to report the crash, on GitHub's bug report form or by email, each filled in from the crash report,
/// which also shows in Finder to attach. A sheet on the key window, where a click outside it is Not Now. At launch the
/// first window may not be key yet, or may show another sheet; the offer then waits for a window it can show on.
@MainActor
enum CrashReportAlert {
    /// While the offer waits for a window, the observers that show it once one becomes key or a sheet on one ends.
    private static var windowObservers: [NSObjectProtocol] = []

    static func show(_ report: FoundCrashReport) {
        if let window = windowForSheet {
            showSheet(about: report, on: window)
            return
        }
        guard windowObservers.isEmpty else { return }
        let center = NotificationCenter.default
        windowObservers = [NSWindow.didBecomeKeyNotification, NSWindow.didEndSheetNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    guard let window = windowForSheet else { return }
                    windowObservers.forEach(center.removeObserver)
                    windowObservers = []
                    showSheet(about: report, on: window)
                }
            }
        }
    }

    private static var windowForSheet: NSWindow? {
        guard let window = NSApp.keyWindow, window.isVisible, window.attachedSheet == nil else { return nil }
        return window
    }

    private static func showSheet(about report: FoundCrashReport, on window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = AppLocalization.string("JustSessions quit unexpectedly")
        alert.informativeText = AppLocalization.string(
            "Reporting the crash helps get it fixed. The report opens with the crash details filled in: add what you were doing, then send it. The crash report file shows in Finder, so you can attach it."
        )
        alert.addButton(withTitle: AppLocalization.string("Report on GitHub"))
        alert.addButton(withTitle: AppLocalization.string("Report by Email"))
        alert.addButton(withTitle: AppLocalization.string("Not Now")).keyEquivalent = "\u{1b}"
        let clickOutsideMonitor = SheetClickOutsideMonitor(window: window) {
            window.endSheet(alert.window, returnCode: .alertThirdButtonReturn)
            return true
        }
        Task {
            let response = await alert.beginSheetModal(for: window)
            clickOutsideMonitor.stop()
            respond(to: response, about: report)
        }
    }

    private static func respond(to response: NSApplication.ModalResponse, about report: FoundCrashReport) {
        let fileName = report.file.lastPathComponent
        let reportLink: URL
        switch response {
        case .alertFirstButtonReturn: reportLink = CrashReportLinks.gitHubIssueURL(for: report.summary, reportFileName: fileName)
        case .alertSecondButtonReturn: reportLink = CrashReportLinks.emailURL(for: report.summary, reportFileName: fileName)
        default: return
        }
        NSWorkspace.shared.activateFileViewerSelecting([report.file])
        NSWorkspace.shared.open(reportLink)
    }
}
