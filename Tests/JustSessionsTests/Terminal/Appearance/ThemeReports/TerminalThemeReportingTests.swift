import Testing
@testable import JustSessions

/// tmux subscribes to theme changes and asks for the current theme as it attaches; the tab answers both.
struct TerminalThemeReportingTests {
    @Test func answersTheThemeQueryAndReportsChangesOnlyWhileSubscribed() {
        var reporting = TerminalThemeReporting()
        #expect(reporting.reportAfterColorChange(isDark: true) == nil)

        let reports = reporting.reports(answering: output("\u{1B}[?2031h\u{1B}[?996n"), isDark: false)

        #expect(reports == ["\u{1B}[?997;2n"])
        #expect(reporting.reportAfterColorChange(isDark: true) == "\u{1B}[?997;1n")
        _ = reporting.reports(answering: output("\u{1B}[?2031l"), isDark: true)
        #expect(reporting.reportAfterColorChange(isDark: true) == nil)
    }

    @Test func findsRequestsSplitAcrossReadsAndAmongOtherOutput() {
        var reporting = TerminalThemeReporting()

        let firstReports = reporting.reports(answering: output("text \u{1B}[?20"), isDark: true)
        let secondReports = reporting.reports(answering: output("31h more \u{1B}[?99"), isDark: true)
        let thirdReports = reporting.reports(answering: output("6n"), isDark: true)

        #expect(firstReports.isEmpty && secondReports.isEmpty)
        #expect(thirdReports == ["\u{1B}[?997;1n"])
        #expect(reporting.isSubscribed)
    }

    @Test func subscribesWhenTheModeIsOneOfSeveral() {
        var reporting = TerminalThemeReporting()

        _ = reporting.reports(answering: output("\u{1B}[?1004;2031h"), isDark: false)

        #expect(reporting.isSubscribed)
    }

    @Test func ignoresOtherSequences() {
        var reporting = TerminalThemeReporting()

        let reports = reporting.reports(
            answering: output("\u{1B}[2031h\u{1B}[?20310h\u{1B}[?6n\u{1B}[?996;1n\u{1B}]11;?\u{1B}\\"),
            isDark: false
        )

        #expect(reports.isEmpty)
        #expect(!reporting.isSubscribed)
    }

    private func output(_ text: String) -> ArraySlice<UInt8> {
        Array(text.utf8)[...]
    }
}
