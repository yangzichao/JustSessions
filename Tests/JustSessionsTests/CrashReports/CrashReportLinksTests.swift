import Foundation
import Testing
@testable import JustSessions

struct CrashReportLinksTests {
    private let reportFileName = "JustSessions-2026-10-05-100000.ips"

    private func summary(body: [String: Any] = CrashReportSamples.swiftRuntimeErrorBody()) throws -> CrashReportSummary {
        try #require(CrashReportSummary(reportText: CrashReportSamples.reportText(body: body)))
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    @Test func gitHubIssueOpensTheBugReportFormWithTheCrashFilledIn() throws {
        let url = CrashReportLinks.gitHubIssueURL(for: try summary(), reportFileName: reportFileName)

        #expect(url.absoluteString.hasPrefix("https://github.com/yangzichao/JustSessions/issues/new?template=bug_report.yml&"))
        #expect(queryValue("title", in: url) == "Crash: EXC_BREAKPOINT (SIGTRAP) in JustSessions 1.0.5 (12)")
        #expect(queryValue("app-version", in: url) == "1.0.5 (12)")
        #expect(queryValue("macos-version", in: url) == "macOS 26.5.1 (25F80)")
        #expect(queryValue("actual-behavior", in: url) == "JustSessions quit unexpectedly.")
        #expect(queryValue("supporting-details", in: url) == """
            Crash report JustSessions-2026-10-05-100000.ips, in ~/Library/Logs/DiagnosticReports

            ```
            Exception: EXC_BREAKPOINT (SIGTRAP)

            Crashed thread (com.apple.root.user-initiated-qos):
            0  libswiftCore.dylib  _assertionFailure(_:_:file:line:flags:)
            1  JustSessions  ConversationStore.removeDeletedConversations(_:) (ConversationStore.swift:494)
            2  JustSessions  0x2000
            3  ???  0x10
            ```
            """)
    }

    /// GitHub fills a form's fields by their ids; a renamed field would quietly stay empty.
    @Test func everyFilledFieldIsOnTheBugReportForm() throws {
        let form = try RepositoryFiles.contents(of: ".github/ISSUE_TEMPLATE/\(CrashReportLinks.bugReportTemplate)")
        let url = CrashReportLinks.gitHubIssueURL(for: try summary(), reportFileName: reportFileName)
        let fieldIDs = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map(\.name)
            .filter { !["template", "title"].contains($0) }

        #expect(fieldIDs.count == 4)
        for fieldID in fieldIDs {
            #expect(form.contains("id: \(fieldID)\n"), "No field \(fieldID) on the bug report form")
        }
    }

    @Test func anObjectiveCExceptionBacktraceComesBeforeTheThreadThatRethrewIt() throws {
        let details = CrashReportLinks.details(of: try summary(body: CrashReportSamples.objectiveCExceptionBody()), reportFileName: reportFileName)

        #expect(details.contains("""
            Exception: EXC_CRASH (SIGABRT)
            CoreFoundation: *** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. 2]
            libsystem_c.dylib: abort() called

            Last exception backtrace:
            0  CoreFoundation  __exceptionPreprocess
            """))
        let exceptionBacktrace = try #require(details.range(of: "Last exception backtrace:"))
        let crashedThread = try #require(details.range(of: "Crashed thread (com.apple.main-thread):"))
        #expect(exceptionBacktrace.lowerBound < crashedThread.lowerBound)
    }

    @Test func longDetailsDropTheLastFramesAndSayTheyAreCut() throws {
        let details = CrashReportLinks.details(
            of: try summary(body: CrashReportSamples.longBacktraceBody(frameCount: 40, symbolLength: 400)),
            reportFileName: reportFileName
        )

        #expect(details.count <= CrashReportLinks.maximumDetailsLength)
        #expect(details.count > CrashReportLinks.maximumDetailsLength - CrashReportSummary.maximumFrameLength - 2)
        #expect(details.hasPrefix("Crash report \(reportFileName)"))
        #expect(details.contains("Exception: EXC_CRASH (SIGABRT)\n\nLast exception backtrace:\n0  JustSessions  frame0_"))
        #expect(details.hasSuffix("\n…\n```"))
    }

    @Test func plusSignsReachGitHubAndMailAsPlusSigns() throws {
        let summary = try summary(body: CrashReportSamples.oneFrameBody(symbol: "std::__1::operator+(int, int)"))
        let urls = [
            CrashReportLinks.gitHubIssueURL(for: summary, reportFileName: reportFileName),
            CrashReportLinks.emailURL(for: summary, reportFileName: reportFileName),
        ]

        for url in urls {
            #expect(!url.absoluteString.contains("+"))
            #expect(url.absoluteString.contains("operator%2B"))
        }
        #expect(queryValue("supporting-details", in: urls[0])?.contains("0  libc++.1.dylib  std::__1::operator+(int, int)") == true)
    }

    @Test func emailAsksWhatYouWereDoingThenGivesTheVersionsAndTheCrash() throws {
        let summary = try summary()
        let url = CrashReportLinks.emailURL(for: summary, reportFileName: reportFileName)

        #expect(url.absoluteString.hasPrefix("mailto:zichaoyangphys@gmail.com?"))
        #expect(queryValue("subject", in: url) == "Crash: EXC_BREAKPOINT (SIGTRAP) in JustSessions 1.0.5 (12)")
        let body = try #require(queryValue("body", in: url))
        #expect(body.hasPrefix("What I was doing when it quit:\n\n\n\nJustSessions 1.0.5 (12) · macOS 26.5.1 (25F80)\n\n"))
        #expect(body.hasSuffix(CrashReportLinks.details(of: summary, reportFileName: reportFileName)))
    }
}
