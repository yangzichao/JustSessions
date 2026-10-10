import AppKit
import Foundation
import Testing
@testable import JustSessions

/// Measures reading a session full of screenshots for message search, with each image's base64 decoded and its header
/// read, as the reader does, and without, as message search does. Reports `Perf | <scenario> | <metric> | <value>` lines;
/// a session without images is the control.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter MessageSearchImageMeasurements
@Suite(.serialized)
struct MessageSearchImageMeasurements {
    @Test(arguments: [0, 30])
    func readingASessionForSearch(imageCount: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let fileSize = try Self.writeClaudeSession(to: file, imageCount: imageCount)
        let scenario = "Claude session with \(imageCount) screenshots, \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))"

        for readsImageData in [true, false] {
            var wallTimes: [Duration] = []
            var cpuTimes: [Duration] = []
            var result = (entryCount: 0, largestPageImageBytes: 0)
            for _ in 0..<5 {
                let cpuStart = Self.processCPUTime()
                let wallTime = try await ContinuousClock().measure {
                    result = try await Self.readWholeSession(file, readsImageData: readsImageData)
                }
                wallTimes.append(wallTime)
                cpuTimes.append(Self.processCPUTime() - cpuStart)
            }
            let mode = readsImageData ? "images decoded" : "images left undecoded"
            perfReport(scenario, "\(mode): entries", result.entryCount)
            perfReport(scenario, "\(mode): image bytes the largest page holds",
                       ByteCountFormatter.string(fromByteCount: Int64(result.largestPageImageBytes), countStyle: .memory))
            perfReport(scenario, "\(mode): median wall time of 5", wallTimes.sorted()[2])
            perfReport(scenario, "\(mode): median CPU time of 5", cpuTimes.sorted()[2])
        }
        #expect(fileSize > 0) // Record-only: the numbers above are the result.
    }

    /// What `SessionMessageTextReader` does, with the image mode chosen. Each page's entries stay in memory until the
    /// next page is read, so the largest page's image bytes are held at once.
    private static func readWholeSession(_ file: URL, readsImageData: Bool) async throws -> (entryCount: Int, largestPageImageBytes: Int) {
        let source = TranscriptPageSource(
            file: file, provider: .claude, limits: SessionMessageTextReader.wholeSessionLimits, readsImageData: readsImageData
        )
        var entryCount = 0
        var largestPageImageBytes = 0
        var request = TranscriptPageRequest.first
        while true {
            let page = try await source.read(request)
            entryCount += page.entries.count
            let imageBytes = page.entries.reduce(0) { total, entry in
                switch entry.content {
                case .userImage(let image), .toolResultImage(let image): total + image.data.count
                default: total
                }
            }
            largestPageImageBytes = max(largestPageImageBytes, imageBytes)
            guard page.hasLater else { return (entryCount, largestPageImageBytes) }
            request = .after(page.records.upperBound)
        }
    }

    /// Prompts and replies, with a pasted screenshot after every fifth prompt and a tool's after every fifth reply.
    /// Each screenshot is a 1280×800 PNG of noise, which compresses little, as a real screenshot's photos and
    /// gradients don't either.
    private static func writeClaudeSession(to file: URL, imageCount: Int) throws -> Int {
        let base64 = try noisePNG(width: 1280, height: 800).base64EncodedString()
        var lines: [String] = []
        var imagesWritten = 0
        for index in 0..<200 {
            let prompt = "Prompt \(index): check the layout of the settings page and the sidebar."
            if index % 5 == 0, imagesWritten < imageCount {
                imagesWritten += 1
                lines.append(#"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"\#(prompt)"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(base64)"}}]}}"#)
            } else {
                lines.append(#"{"type":"user","message":{"role":"user","content":"\#(prompt)"}}"#)
            }
            lines.append(#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Reply \#(index): the layout fits."},{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/screenshot-\#(index).png"}}]}}"#)
            if index % 5 == 2, imagesWritten < imageCount {
                imagesWritten += 1
                lines.append(#"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(base64)"}}]}]}}"#)
            }
        }
        let data = SampleTranscriptLines.fileContents(lines)
        try data.write(to: file)
        return data.count
    }

    private static func noisePNG(width: Int, height: Int) throws -> Data {
        var generator = SeededRandomNumberGenerator(seed: 7)
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 3,
            hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 3, bitsPerPixel: 24
        ))
        let pixels = try #require(bitmap.bitmapData)
        for offset in 0..<(width * height * 3) { pixels[offset] = UInt8.random(in: 0...255, using: &generator) }
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private static func processCPUTime() -> Duration {
        var time = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
        return .seconds(time.tv_sec) + .nanoseconds(time.tv_nsec)
    }
}
