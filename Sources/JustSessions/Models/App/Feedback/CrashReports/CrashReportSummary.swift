import Foundation

struct CrashReportSummary: Equatable, Sendable {
    let bundleIdentifier: String
    let appVersion: String
    let macOSVersion: String
    let exception: String?
    let crashMessages: [String]
    let crashedThreadQueue: String?
    let crashedThreadFrames: [String]
    let lastExceptionFrames: [String]

    static let maximumFramesPerBacktrace = 16
    static let maximumFrameLength = 160
    static let maximumCrashMessages = 4
    static let maximumCrashMessageLength = 300

    init?(reportText: String) {
        let parts = reportText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let headerLine = parts.first,
            let header = try? JSONDecoder().decode(CrashReportFileFormat.Header.self, from: Data(headerLine.utf8)),
            header.bugType == CrashReportFileFormat.crashBugType,
            let bundleIdentifier = header.bundleIdentifier, !bundleIdentifier.isEmpty
        else { return nil }
        let body =
            parts.count > 1
            ? try? JSONDecoder().decode(CrashReportFileFormat.Body.self, from: Data(parts[1].utf8))
            : nil

        self.bundleIdentifier = bundleIdentifier
        appVersion = FeedbackEnvironment.appVersion(shortVersion: header.appVersion, buildNumber: header.buildVersion)
        macOSVersion = header.macOSVersion.flatMap { $0.isEmpty ? nil : $0 } ?? "macOS (unknown version)"
        exception = body?.exception.flatMap(Self.describe)
        crashMessages = (body?.applicationSpecificInformation ?? [:])
            .sorted { $0.key < $1.key }
            .flatMap { library, messages in messages.map { "\(library): \($0)" } }
            .prefix(Self.maximumCrashMessages)
            .map { Self.shortened($0, to: Self.maximumCrashMessageLength) }
        let images = body?.usedImages ?? []
        let crashedThread = body.flatMap { body in
            body.faultingThread.flatMap { index in body.threads.flatMap { $0.indices.contains(index) ? $0[index] : nil } }
        }
        crashedThreadQueue = crashedThread?.queue
        crashedThreadFrames = Self.describe(crashedThread?.frames ?? [], images: images)
        lastExceptionFrames = Self.describe(body?.lastExceptionBacktrace ?? [], images: images)
    }

    private static func describe(_ exception: CrashReportFileFormat.Exception) -> String? {
        switch (exception.type, exception.signal) {
        case (let type?, let signal?): "\(type) (\(signal))"
        case (let type?, nil): type
        case (nil, let signal?): signal
        case (nil, nil): nil
        }
    }

    private static func describe(_ frames: [CrashReportFileFormat.Frame], images: [CrashReportFileFormat.Image]) -> [String] {
        frames.prefix(maximumFramesPerBacktrace).enumerated().map { index, frame in
            let imageName = frame.imageIndex.flatMap { images.indices.contains($0) ? images[$0].name : nil } ?? "???"
            var line = "\(index)  \(imageName)  "
            if let symbol = frame.symbol {
                line += symbol
            } else {
                line += "0x" + String(frame.imageOffset ?? 0, radix: 16)
            }
            if let sourceFile = frame.sourceFile, let sourceLine = frame.sourceLine {
                line += " (\(URL(fileURLWithPath: sourceFile).lastPathComponent):\(sourceLine))"
            }
            return shortened(line, to: maximumFrameLength)
        }
    }

    private static func shortened(_ text: String, to limit: Int) -> String {
        let singleLine = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return singleLine.count > limit ? singleLine.prefix(limit - 1) + "…" : singleLine
    }
}
