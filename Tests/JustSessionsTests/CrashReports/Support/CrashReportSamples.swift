import Foundation

/// Crash reports in the shape macOS writes them, a line of JSON about the report and then the report as JSON, with
/// made-up frames and paths.
enum CrashReportSamples {
    static let bundleIdentifier = "dev.zichaoyang.justsessions"

    static func reportText(
        bugType: String = "309",
        bundleIdentifier: String? = CrashReportSamples.bundleIdentifier,
        appVersion: String = "1.0.5",
        buildVersion: String = "12",
        body: [String: Any] = swiftRuntimeErrorBody()
    ) -> String {
        var header: [String: Any] = [
            "app_name": "JustSessions",
            "timestamp": "2026-10-05 10:00:00.00 -0700",
            "app_version": appVersion,
            "build_version": buildVersion,
            "bug_type": bugType,
            "os_version": "macOS 26.5.1 (25F80)",
            "name": "JustSessions",
        ]
        if let bundleIdentifier { header["bundleID"] = bundleIdentifier }
        return json(header, options: []) + "\n" + json(body, options: [.prettyPrinted])
    }

    /// A Swift runtime error off the main thread: one frame with its source file, one without a symbol, and one
    /// whose image the report does not list.
    static func swiftRuntimeErrorBody() -> [String: Any] {
        [
            "procPath": "/Users/someone/Applications/JustSessions.app/Contents/MacOS/JustSessions",
            "exception": ["type": "EXC_BREAKPOINT", "signal": "SIGTRAP", "codes": "0x0000000000000001, 0x00000001a0f88cc8"],
            "faultingThread": 1,
            "threads": [
                ["id": 1, "queue": "com.apple.main-thread", "frames": [["imageIndex": 1, "imageOffset": 64, "symbol": "main"]]],
                [
                    "id": 2,
                    "triggered": true,
                    "queue": "com.apple.root.user-initiated-qos",
                    "frames": [
                        ["imageIndex": 0, "imageOffset": 1_445_064, "symbol": "_assertionFailure(_:_:file:line:flags:)", "symbolLocation": 172],
                        [
                            "imageIndex": 1, "imageOffset": 4096, "symbol": "ConversationStore.removeDeletedConversations(_:)",
                            "symbolLocation": 40,
                            "sourceFile": "/Users/builder/JustSessions/Sources/JustSessions/Services/Store/ConversationStore.swift",
                            "sourceLine": 494,
                        ],
                        ["imageIndex": 1, "imageOffset": 8192],
                        ["imageIndex": 9, "imageOffset": 16],
                    ],
                ],
            ],
            "usedImages": [
                ["name": "libswiftCore.dylib", "path": "/usr/lib/swift/libswiftCore.dylib"],
                ["name": "JustSessions", "path": "/Users/someone/Applications/JustSessions.app/Contents/MacOS/JustSessions"],
            ],
        ]
    }

    /// An Objective-C exception: the crashed thread only aborts, and the exception's own backtrace says where it was raised.
    static func objectiveCExceptionBody() -> [String: Any] {
        [
            "exception": ["type": "EXC_CRASH", "signal": "SIGABRT"],
            "asi": [
                "libsystem_c.dylib": ["abort() called"],
                "CoreFoundation": ["*** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. 2]"],
            ],
            "faultingThread": 0,
            "threads": [[
                "queue": "com.apple.main-thread",
                "triggered": true,
                "frames": [["imageIndex": 0, "symbol": "__pthread_kill"], ["imageIndex": 1, "symbol": "abort"]],
            ]],
            "lastExceptionBacktrace": [
                ["imageIndex": 2, "symbol": "__exceptionPreprocess"],
                ["imageIndex": 3, "symbol": "objc_exception_throw"],
                ["imageIndex": 4, "symbol": "-[NSTableRowData _availableRowViewWhileUpdatingAtRow:]"],
            ],
            "usedImages": [
                ["name": "libsystem_kernel.dylib"], ["name": "libsystem_c.dylib"], ["name": "CoreFoundation"],
                ["name": "libobjc.A.dylib"], ["name": "AppKit"],
            ],
        ]
    }

    /// A crashed thread of `frameCount` frames, each with a symbol of `symbolLength` characters, and an Objective-C
    /// exception backtrace as long.
    static func longBacktraceBody(frameCount: Int, symbolLength: Int) -> [String: Any] {
        let frames: [[String: Any]] = (0..<frameCount).map { index in
            ["imageIndex": 0, "symbol": "frame\(index)_" + String(repeating: "x", count: symbolLength)]
        }
        return [
            "exception": ["type": "EXC_CRASH", "signal": "SIGABRT"],
            "faultingThread": 0,
            "threads": [["queue": "com.apple.main-thread", "frames": frames]],
            "lastExceptionBacktrace": frames,
            "usedImages": [["name": "JustSessions"]],
        ]
    }

    /// One crashed frame whose symbol is `symbol`.
    static func oneFrameBody(symbol: String) -> [String: Any] {
        [
            "exception": ["type": "EXC_BAD_ACCESS", "signal": "SIGSEGV"],
            "faultingThread": 0,
            "threads": [["frames": [["imageIndex": 0, "symbol": symbol]]]],
            "usedImages": [["name": "libc++.1.dylib"]],
        ]
    }

    private static func json(_ object: [String: Any], options: JSONSerialization.WritingOptions) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: options.union(.sortedKeys))) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
