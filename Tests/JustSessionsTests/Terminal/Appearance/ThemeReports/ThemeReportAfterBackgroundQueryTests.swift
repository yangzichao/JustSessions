import Testing

@testable import JustSessions

/// tmux before 3.6 hears of a light/dark change only from a client that attaches again and asks for the colors; the
/// tab then reports the change right after answering, and tmux passes the report on to the CLI.
struct ThemeReportAfterBackgroundQueryTests {
    @Test func reportsOnceAfterTheNextBackgroundQuery() {
        var reporting = TerminalThemeReporting()
        reporting.reportAfterNextBackgroundQuery()

        let firstReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]10;?\u{1B}\\\u{1B}]11;?\u{1B}\\"), isDark: false)
        let secondReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]11;?\u{1B}\\"), isDark: false)

        #expect(firstReports == ["\u{1B}[?997;2n"])
        #expect(secondReports.isEmpty)
        #expect(!reporting.reportsAfterNextBackgroundQuery)
    }

    @Test func findsAQueryEndedByABellAndSplitAcrossReads() {
        var reporting = TerminalThemeReporting()
        reporting.reportAfterNextBackgroundQuery()

        let firstReports = reporting.reportsToSendAfterTheTerminalReads(output("text \u{1B}]1"), isDark: true)
        let secondReports = reporting.reportsToSendAfterTheTerminalReads(output("1;?"), isDark: true)
        let thirdReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{07} more"), isDark: true)

        #expect(firstReports.isEmpty && secondReports.isEmpty)
        #expect(thirdReports == ["\u{1B}[?997;1n"])
    }

    @Test func waitsForTheQueryToEndSoTheTerminalAnswersFirst() {
        var reporting = TerminalThemeReporting()
        reporting.reportAfterNextBackgroundQuery()

        let unendedReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]11;?\u{1B}"), isDark: true)
        let endedReports = reporting.reportsToSendAfterTheTerminalReads(output("\\"), isDark: true)

        #expect(unendedReports.isEmpty)
        #expect(endedReports == ["\u{1B}[?997;1n"])
    }

    @Test func ignoresOtherCommandsAndQueriesWhenNoReportIsOwed() {
        var reporting = TerminalThemeReporting()
        let otherCommands = "\u{1B}]11;rgb:0000/0000/0000\u{07}\u{1B}]8;;https://example.com/11;?\u{1B}\\\u{1B}]111;?\u{07}"

        let unowedReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]11;?\u{1B}\\"), isDark: false)
        reporting.reportAfterNextBackgroundQuery()
        let otherCommandReports = reporting.reportsToSendAfterTheTerminalReads(output(otherCommands), isDark: false)
        reporting.cancelReportAfterNextBackgroundQuery()
        let cancelledReports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]11;?\u{1B}\\"), isDark: false)

        #expect(unowedReports.isEmpty)
        #expect(otherCommandReports.isEmpty)
        #expect(cancelledReports.isEmpty)
    }

    @Test func findsARequestThatInterruptsAnUnendedCommand() {
        var reporting = TerminalThemeReporting()

        let reports = reporting.reportsToSendAfterTheTerminalReads(output("\u{1B}]0;title\u{1B}[?2031h\u{1B}[?996n"), isDark: true)

        #expect(reporting.isSubscribed)
        #expect(reports == ["\u{1B}[?997;1n"])
    }

    private func output(_ text: String) -> ArraySlice<UInt8> {
        Array(text.utf8)[...]
    }
}
