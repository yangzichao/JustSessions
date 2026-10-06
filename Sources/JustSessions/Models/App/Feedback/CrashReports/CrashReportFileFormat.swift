import Foundation

/// The parts of a macOS crash report (`.ips`) the summary reads. The file is one line of JSON about the report, then
/// the report itself as JSON. Every field is optional, so a field macOS drops or renames leaves only that part out.
enum CrashReportFileFormat {
    /// `bug_type` 309 is a crash; macOS writes hangs and other reports in the same format under other types.
    static let crashBugType = "309"

    struct Header: Decodable {
        let bugType: String?
        let bundleIdentifier: String?
        let appVersion: String?
        let buildVersion: String?
        let macOSVersion: String?

        enum CodingKeys: String, CodingKey {
            case bugType = "bug_type"
            case bundleIdentifier = "bundleID"
            case appVersion = "app_version"
            case buildVersion = "build_version"
            case macOSVersion = "os_version"
        }
    }

    struct Body: Decodable {
        let exception: Exception?
        /// Messages the crashing libraries left, by library, such as `abort() called` or a Swift runtime error.
        let applicationSpecificInformation: [String: [String]]?
        let faultingThread: Int?
        let threads: [Thread]?
        let usedImages: [Image]?
        /// Where an Objective-C exception was raised; the crashed thread then only shows it being rethrown.
        let lastExceptionBacktrace: [Frame]?

        enum CodingKeys: String, CodingKey {
            case exception, faultingThread, threads, usedImages, lastExceptionBacktrace
            case applicationSpecificInformation = "asi"
        }
    }

    struct Exception: Decodable {
        let type: String?
        let signal: String?
    }

    struct Thread: Decodable {
        let queue: String?
        let frames: [Frame]?
    }

    struct Frame: Decodable {
        let imageIndex: Int?
        let imageOffset: Int?
        let symbol: String?
        let sourceFile: String?
        let sourceLine: Int?
    }

    struct Image: Decodable {
        let name: String?
    }
}
