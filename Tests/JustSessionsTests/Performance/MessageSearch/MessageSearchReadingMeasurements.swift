import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Reads generated sessions page by page, as `SessionMessageTextReader` reads one for message search, once decoding
/// their images and once leaving them undecoded, as `Perf | <scenario> | <metric> | <value>` lines.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter MessageSearchReadingMeasurements
@Suite(.serialized)
struct MessageSearchReadingMeasurements {
    static let messageCount = 100
    static let runCount = 5

    /// 0 is the text-only control. 160 KiB and 745 KiB are the median and 90th percentile base64 length of 6,619
    /// images in one contributor's Codex sessions, October 2026.
    @Test(arguments: [0, 160 << 10, 745 << 10])
    func readingForSearch(imageBase64Length: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let imageBase64 = imageBase64Length > 0 ? ImageHeavySessionFixture.noisePNGBase64(length: imageBase64Length) : nil
        for provider in [ConversationProvider.claude, .codex] {
            let file = try ImageHeavySessionFixture.write(
                provider: provider, messageCount: Self.messageCount, imageBase64: imageBase64, in: directory
            )
            let images = imageBase64.map { "\(Self.messageCount) images of \($0.count >> 10) KiB base64" } ?? "no images"
            let label = "search read, \(provider.rawValue), \(images)"
            for decodesImages in [true, false] {
                _ = try await read(file, provider: provider, decodesImages: decodesImages) // Warms the file cache.
                var wallTimes: [Duration] = []
                var cpuTimes: [Duration] = []
                var largestPageImageBytes = 0
                for _ in 0..<Self.runCount {
                    let cpuStart = Self.processCPUTime()
                    let wallStart = ContinuousClock.now
                    largestPageImageBytes = try await read(file, provider: provider, decodesImages: decodesImages)
                    wallTimes.append(ContinuousClock.now - wallStart)
                    cpuTimes.append(Self.processCPUTime() - cpuStart)
                }
                let mode = decodesImages ? "decoding images" : "images undecoded"
                perfReport(label, "\(mode): median wall time", wallTimes.sorted()[Self.runCount / 2])
                perfReport(label, "\(mode): median CPU time", cpuTimes.sorted()[Self.runCount / 2])
                perfReport(label, "\(mode): decoded image bytes one page holds", "\(largestPageImageBytes >> 10) KiB")
            }
        }
    }

    /// Reads every page and returns the most decoded image bytes one page held.
    private func read(_ file: URL, provider: ConversationProvider, decodesImages: Bool) async throws -> Int {
        let source = TranscriptPageSource(
            file: file, provider: provider, limits: SessionMessageTextReader.wholeSessionLimits, decodesImages: decodesImages
        )
        var largestPageImageBytes = 0
        var request = TranscriptPageRequest.first
        while true {
            let page = try await source.read(request)
            let imageBytes = page.entries.reduce(0) { total, entry in
                switch entry.content {
                case .userImage(let image), .toolResultImage(let image): total + image.data.count
                default: total
                }
            }
            largestPageImageBytes = max(largestPageImageBytes, imageBytes)
            guard page.hasLater else { return largestPageImageBytes }
            request = .after(page.records.upperBound)
        }
    }

    private static func processCPUTime() -> Duration {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let microseconds = Int64(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1_000_000
            + Int64(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec)
        return .microseconds(microseconds)
    }
}
