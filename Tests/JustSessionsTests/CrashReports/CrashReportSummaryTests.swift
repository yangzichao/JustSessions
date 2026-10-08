import Foundation
import Testing
@testable import JustSessions

struct CrashReportSummaryTests {
    @Test func readsTheVersionsTheExceptionAndTheCrashedThreadWithoutPaths() throws {
        let summary = try #require(CrashReportSummary(reportText: CrashReportSamples.reportText()))

        #expect(summary.bundleIdentifier == CrashReportSamples.bundleIdentifier)
        #expect(summary.appVersion == "1.0.5 (12)")
        #expect(summary.macOSVersion == "macOS 26.5.1 (25F80)")
        #expect(summary.exception == "EXC_BREAKPOINT (SIGTRAP)")
        #expect(summary.crashMessages.isEmpty)
        #expect(summary.crashedThreadQueue == "com.apple.root.user-initiated-qos")
        #expect(summary.crashedThreadFrames == [
            "0  libswiftCore.dylib  _assertionFailure(_:_:file:line:flags:)",
            "1  JustSessions  ConversationStore.removeDeletedConversations(_:) (ConversationStore.swift:494)",
            "2  JustSessions  0x2000",
            "3  ???  0x10",
        ])
        #expect(summary.lastExceptionFrames.isEmpty)
        #expect(!summary.crashedThreadFrames.contains { $0.contains("/Users/") })
    }

    @Test func anObjectiveCExceptionKeepsWhereItWasRaisedAndWhatTheLibrariesSaid() throws {
        let summary = try #require(CrashReportSummary(
            reportText: CrashReportSamples.reportText(body: CrashReportSamples.objectiveCExceptionBody())
        ))

        #expect(summary.exception == "EXC_CRASH (SIGABRT)")
        #expect(summary.crashMessages == [
            "CoreFoundation: *** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. 2]",
            "libsystem_c.dylib: abort() called",
        ])
        #expect(summary.crashedThreadQueue == "com.apple.main-thread")
        #expect(summary.crashedThreadFrames == ["0  libsystem_kernel.dylib  __pthread_kill", "1  libsystem_c.dylib  abort"])
        #expect(summary.lastExceptionFrames == [
            "0  CoreFoundation  __exceptionPreprocess",
            "1  libobjc.A.dylib  objc_exception_throw",
            "2  AppKit  -[NSTableRowData _availableRowViewWhileUpdatingAtRow:]",
        ])
    }

    @Test func aBuildWithTheSameVersionAndBuildNumberShowsTheVersionOnce() throws {
        let summary = try #require(CrashReportSummary(reportText: CrashReportSamples.reportText(appVersion: "1.0.5", buildVersion: "1.0.5")))
        #expect(summary.appVersion == "1.0.5")
    }

    @Test(arguments: ["298", "288", ""])
    func anotherKindOfReportIsNoCrash(_ bugType: String) {
        #expect(CrashReportSummary(reportText: CrashReportSamples.reportText(bugType: bugType)) == nil)
    }

    @Test(arguments: [nil, ""] as [String?])
    func aCrashOfABuildWithoutABundleIsLeftOut(_ bundleIdentifier: String?) {
        #expect(CrashReportSummary(reportText: CrashReportSamples.reportText(bundleIdentifier: bundleIdentifier)) == nil)
    }

    @Test(arguments: ["", "not a report", "{\"bug_type\": 309}\n{}"])
    func textThatIsNoCrashReportGivesNoSummary(_ text: String) {
        #expect(CrashReportSummary(reportText: text) == nil)
    }

    @Test func aReportWhoseBodyCannotBeReadStillGivesTheVersions() throws {
        let header = try #require(CrashReportSamples.reportText().split(separator: "\n").first)
        let summary = try #require(CrashReportSummary(reportText: header + "\n{ not json"))

        #expect(summary.appVersion == "1.0.5 (12)")
        #expect(summary.exception == nil)
        #expect(summary.crashedThreadFrames.isEmpty)
        #expect(summary.lastExceptionFrames.isEmpty)
    }

    @Test func longBacktracesKeepTheInnermostFramesEachOnOneShortLine() throws {
        let summary = try #require(CrashReportSummary(reportText: CrashReportSamples.reportText(
            body: CrashReportSamples.longBacktraceBody(frameCount: 40, symbolLength: 400)
        )))

        for frames in [summary.crashedThreadFrames, summary.lastExceptionFrames] {
            #expect(frames.count == CrashReportSummary.maximumFramesPerBacktrace)
            #expect(frames.first?.hasPrefix("0  JustSessions  frame0_") == true)
            #expect(frames.allSatisfy { $0.count == CrashReportSummary.maximumFrameLength && $0.hasSuffix("…") })
        }
    }
}
