import Foundation
import SwiftUI
import Testing

@testable import JustSessions

/// Measures reading a tab's conversation-map outline (PERF-90), as `ConversationOutlineReader` does off the main
/// thread: a cold read, a read after a one-record append, a read after the file is replaced by a copy with one more
/// record (as rsync leaves an SSH mirror), a change check, ⌘D's newest message cold and warm, and the outline's size
/// a block and a message; and drawing a 10,000-block map in its one Canvas (PERF-89). Reports `Perf | <scenario> | <metric> | <value>` lines, medians of `runCount`.
///
/// Fixtures: the 27 MiB realistic and 100 MiB synthetic Codex logs of `IncrementalMessageSearchMeasurements`, a
/// generated Pi file of about 95 MiB in `SampleTranscriptLines.pi`'s shape, and a 10,000-message OpenCode session as
/// `OpenCodeTranscriptPagingMeasurements` builds it.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter ConversationOutlineMeasurements
/// `JUSTSESSIONS_PERF_FIXTURES` picks fixtures, such as `codex27,pi95`; all four run by default.
@Suite(.serialized)
struct ConversationOutlineMeasurements {
    static let runCount = 5
    static let checkCount = 10_000
    static let renderCount = 20

    @Test(arguments: ["codex27", "codex100", "pi95", "opencode10k"])
    func readingAnOutline(fixture name: String) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        if let picked = ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_FIXTURES"],
            !picked.split(separator: ",").contains(Substring(name))
        {
            return
        }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try MeasuredSession(name, in: directory)
        let scenario = fixture.scenario
        let size = try FileManager.default.attributesOfItem(atPath: fixture.conversation.sourceFile.path)[.size] as! Int
        perfReport(scenario, "file", "\(size) bytes")

        var outline: ConversationOutline?
        perfReport(
            scenario, "cold update()",
            try await Self.median {
                outline = try await ConversationOutlineReader(fixture.conversation).update()
            })
        let blocks = try #require(outline).blocks
        perfReport(scenario, "blocks, messages", "\(blocks.count), \(outline!.messageCount)")
        perfReport(scenario, "outline bytes a block", Self.footprint(of: blocks) / max(1, blocks.count))
        // PERF-90 states it a message: tool runs' blocks are counted in.
        perfReport(scenario, "outline bytes a message", Self.footprint(of: blocks) / max(1, outline!.messageCount))

        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        var appendTimes: [Duration] = []
        for run in 0..<Self.runCount {
            try fixture.appendRecord(run)
            let start = ContinuousClock.now
            _ = try await reader.update()
            appendTimes.append(ContinuousClock.now - start)
        }
        perfReport(scenario, "one-record append update()", appendTimes.sorted()[appendTimes.count / 2])

        if fixture.isFile {
            var replaceTimes: [Duration] = []
            for run in 0..<Self.runCount {
                try fixture.replaceWithCopy(appending: Self.runCount + run, in: directory)
                let start = ContinuousClock.now
                _ = try await reader.update()
                replaceTimes.append(ContinuousClock.now - start)
            }
            perfReport(scenario, "replaced copy update()", replaceTimes.sorted()[replaceTimes.count / 2])
        }

        let checkStart = ContinuousClock.now
        for _ in 0..<Self.checkCount { _ = await reader.hasChanged() }
        let perCheck = (ContinuousClock.now - checkStart) / Self.checkCount
        perfReport(scenario, "hasChanged()", String(format: "%.1f µs", Double(perCheck.components.attoseconds) / 1e12))

        perfReport(
            scenario, "latestMessage() cold",
            try await Self.median {
                _ = try await ConversationOutlineReader(fixture.conversation).latestMessage()
            })
        let warm = ConversationOutlineReader(fixture.conversation)
        _ = try await warm.latestMessage()
        perfReport(
            scenario, "latestMessage() warm",
            try await Self.median {
                _ = try await warm.latestMessage()
            })
        #expect(!blocks.isEmpty)  // Record-only: the numbers above are the result.
    }

    private static func tenThousandBlocks() -> [ConversationOutline.Block] {
        let kinds: [ConversationOutline.Block.Kind] = [.user, .assistant, .toolRun, .assistant]
        return (0..<10_000).map { index in
            let kind = kinds[index % kinds.count]
            return ConversationOutline.Block(
                entryID: TranscriptPageIdentity.entryID(record: index, part: 0), lastRecord: index, kind: kind, timestamp: nil,
                snippet: "Block \(index)", lineWidths: kind == .toolRun ? [40, 32] : [80, 80, 56, 0, 72],
                toolCallCount: kind == .toolRun ? 2 : 0
            )
        }
    }

    /// The "Canvas draws" row: `ConversationMapCanvas` in a 110 × 800 column at 2× with 10,000 blocks, squeezed to one bar
    /// a pixel row, and 26 bookmarks with their letters, rendered `renderCount` times. Runs on `main` too, to compare.
    @MainActor
    @Test func drawingAMapOfTenThousandBlocks() {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let blocks = Self.tenThousandBlocks()
        let outline = ConversationOutline(blocks: blocks)
        let size = CGSize(width: 110, height: 800)
        let chipSide: CGFloat = 14
        let layout = ConversationMapLayout(
            rowCount: outline.rowCount, height: size.height, naturalPitch: 3,
            verticalInset: ConversationMapMetrics.verticalInset)
        let bookmarks = "abcdefghijklmnopqrstuvwxyz".enumerated().map { offset, letter in
            MessageBookmark(letter: String(letter), entryID: blocks[offset * 384 + 1].entryID, kind: .assistant, snippet: "")
        }
        let canvas = ConversationMapCanvas(
            outline: outline, layout: layout, chips: layout.chips(for: bookmarks, in: outline, side: chipSide, height: size.height),
            colors: ConversationMapColors(palette: AppThemeColors.justSessionsLight.terminalPalette, provider: .claude),
            pixel: 0.5, chipSide: chipSide, letterFont: ThemeFont.caption.weight(.semibold)
        )
        var times: [Duration] = []
        for _ in 0..<Self.renderCount {
            let renderer = ImageRenderer(content: canvas.frame(width: size.width, height: size.height))
            renderer.scale = 2
            let start = ContinuousClock.now
            let image = renderer.cgImage
            times.append(ContinuousClock.now - start)
            #expect(image != nil)
        }
        perfReport("map canvas, 10,000 blocks in 110 × 800 at 2×", "render p50", times.sorted()[times.count / 2])
    }

    /// Scrolling that map at its minimum pitch with 26 labelled bookmarks, as the map does each scroll step: the layout at
    /// the new offset, the chips and their (kept) labels, then the render. 40 steps of 120 points from the top.
    @MainActor
    @Test func scrollingAMapOfTenThousandBlocksWithLabels() {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let blocks = Self.tenThousandBlocks()
        let outline = ConversationOutline(blocks: blocks)
        let size = CGSize(width: 110, height: 800)
        let chipSide: CGFloat = 14
        let bookmarks = "abcdefghijklmnopqrstuvwxyz".enumerated().map { offset, letter in
            var bookmark = MessageBookmark(letter: String(letter), entryID: blocks[offset * 384 + 1].entryID, kind: .assistant, snippet: "")
            bookmark.label = "Label \(letter): the step that fixed the build"
            return bookmark
        }
        let colors = ConversationMapColors(palette: AppThemeColors.justSessionsLight.terminalPalette, provider: .claude)
        _ = ConversationMapChipTitles.titles(for: bookmarks, side: chipSide, factor: 1)
        var stepTimes: [Duration] = []
        var renderTimes: [Duration] = []
        for step in 0..<40 {
            let start = ContinuousClock.now
            let layout = ConversationMapLayout(
                rowCount: outline.rowCount, height: size.height, naturalPitch: 3,
                verticalInset: ConversationMapMetrics.verticalInset, minimumPitch: 1,
                offsetFromTop: CGFloat(step) * 120)
            let chips = layout.chips(
                for: bookmarks, in: outline, side: chipSide, height: size.height,
                titles: ConversationMapChipTitles.titles(for: bookmarks, side: chipSide, factor: 1))
            let canvas = ConversationMapCanvas(
                outline: outline, layout: layout, chips: chips, colors: colors, pixel: 0.5,
                chipSide: chipSide, letterFont: ThemeFont.caption.weight(.semibold))
            let renderer = ImageRenderer(content: canvas.frame(width: size.width, height: size.height))
            renderer.scale = 2
            let renderStart = ContinuousClock.now
            let image = renderer.cgImage
            let end = ContinuousClock.now
            renderTimes.append(end - renderStart)
            stepTimes.append(end - start)
            #expect(image != nil)
            #expect(layout.isScrollable)
        }
        perfReport("map scroll step, 10,000 blocks, 26 labels, 110 × 800 at 2×", "step p50", stepTimes.sorted()[stepTimes.count / 2])
        perfReport("map scroll step, 10,000 blocks, 26 labels, 110 × 800 at 2×", "step p95", stepTimes.sorted()[stepTimes.count * 95 / 100])
        perfReport("map scroll step, 10,000 blocks, 26 labels, 110 × 800 at 2×", "render p50", renderTimes.sorted()[renderTimes.count / 2])
    }

    private static func median(_ work: () async throws -> Void) async throws -> Duration {
        var times: [Duration] = []
        for _ in 0..<runCount {
            let start = ContinuousClock.now
            try await work()
            times.append(ContinuousClock.now - start)
        }
        return times.sorted()[times.count / 2]
    }

    /// The blocks' own storage, their snippets' beyond the 15 bytes a `String` keeps inline, and their line widths'
    /// arrays with a 32-byte header each.
    static func footprint(of blocks: [ConversationOutline.Block]) -> Int {
        blocks.reduce(MemoryLayout<ConversationOutline.Block>.stride * blocks.count + MemoryLayout<Int>.stride * blocks.count) {
            total, block in
            let snippet = block.snippet.utf8.count > 15 ? block.snippet.utf8.count + 32 : 0
            return total + snippet + 32 + block.lineWidths.count
        }
    }

    struct MeasuredSession {
        let scenario: String
        let conversation: Conversation
        let isFile: Bool
        private let name: String
        private let database: OpenCodeDatabaseFixture?
        /// The Pi file's last line, which the first appended prompt continues.
        private let piLastID: String?

        init(_ name: String, in directory: URL) throws {
            self.name = name
            switch name {
            case "opencode10k":
                let database = try OpenCodeDatabaseFixture(file: directory.appendingPathComponent("opencode.db"))
                try OpenCodeTranscriptPagingMeasurements.addSession(to: database, messageCount: 10_000)
                self.database = database
                piLastID = nil
                scenario = "outline, OpenCode session of 10,000 messages"
                conversation = .fixture(
                    provider: .opencode, sessionID: OpenCodeTranscriptPagingMeasurements.sessionID, sourceFile: database.file)
                isFile = false
            case "pi95":
                let file = directory.appendingPathComponent("session.jsonl")
                piLastID = try PiFixture.write(sizeMiB: 95, to: file)
                database = nil
                scenario = "outline, 95 MiB Pi session"
                conversation = .fixture(provider: .pi, sourceFile: file)
                isFile = true
            default:
                let file = directory.appendingPathComponent("session.jsonl")
                if name == "codex27" {
                    try IncrementalMessageSearchMeasurements.RealisticFixture.write(to: file)
                    scenario = "outline, 27 MiB realistic Codex log"
                } else {
                    try IncrementalMessageSearchMeasurements.SyntheticFixture.write(sizeMiB: 100, to: file)
                    scenario = "outline, 100 MiB synthetic Codex log"
                }
                database = nil
                piLastID = nil
                conversation = .fixture(provider: .codex, sourceFile: file)
                isFile = true
            }
        }

        func appendRecord(_ number: Int) throws {
            if let database {
                let createdAt = Int64(1_800_000_000_000 + number * 1_000)
                try database.addAssistantReply(
                    String(format: "msg_appended_%03d", number), session: OpenCodeTranscriptPagingMeasurements.sessionID,
                    createdAt: createdAt, text: "Appended reply \(number)")
                return
            }
            let handle = try FileHandle(forWritingTo: conversation.sourceFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((appendedLine(number) + "\n").utf8))
        }

        /// A new file with one more record, renamed over the session's, so its inode changes.
        func replaceWithCopy(appending number: Int, in directory: URL) throws {
            let copy = directory.appendingPathComponent("copy.jsonl")
            try FileManager.default.copyItem(at: conversation.sourceFile, to: copy)
            let handle = try FileHandle(forWritingTo: copy)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((appendedLine(number) + "\n").utf8))
            try handle.close()
            _ = try FileManager.default.replaceItemAt(conversation.sourceFile, withItemAt: copy)
        }

        private func appendedLine(_ number: Int) -> String {
            switch name {
            case "pi95": PiFixture.appendedLine(number, after: piLastID ?? "")
            case "codex27": IncrementalMessageSearchMeasurements.SyntheticFixture.message("Appended \(number) Café 中文 🧪")
            default: IncrementalMessageSearchMeasurements.SyntheticFixture.appendedLine(number * 2 + 1)
            }
        }
    }

    /// Turns of `SampleTranscriptLines.pi`'s shape, chained by `id` and `parentId`: a prompt, a reply with a tool call,
    /// the tool's result with about 6 KB of output, and a closing reply.
    enum PiFixture {
        static let turnLineCount = 4

        /// Returns the last line's `id`.
        static func write(sizeMiB: Int, to file: URL) throws -> String {
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.write(contentsOf: Data((SampleTranscriptLines.pi[0] + "\n").utf8))
            let target = UInt64(sizeMiB) << 20
            var written: UInt64 = 0
            var turn = 0
            while written < target {
                let data = Data((Self.turn(turn).joined(separator: "\n") + "\n").utf8)
                try handle.write(contentsOf: data)
                written += UInt64(data.count)
                turn += 1
            }
            return "p\((turn - 1) * turnLineCount + 3)"
        }

        static func turn(_ number: Int) -> [String] {
            let base = number * turnLineCount
            let parent = number == 0 ? "null" : "\"p\(base - 1)\""
            let output = IncrementalMessageSearchMeasurements.RealisticFixture.filler(6_000)
            let reply = IncrementalMessageSearchMeasurements.RealisticFixture.filler(900)
            return [
                #"{"type":"message","id":"p\#(base)","parentId":\#(parent),"timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"Turn \#(number): fix the build"}],"timestamp":1758708001000}}"#,
                #"{"type":"message","id":"p\#(base + 1)","parentId":"p\#(base)","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Looking at it. \#(reply)"},{"type":"toolCall","id":"t\#(number)","name":"bash","arguments":{"command":"swift build"}}],"stopReason":"toolUse","timestamp":1758708002000}}"#,
                #"{"type":"message","id":"p\#(base + 2)","parentId":"p\#(base + 1)","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"toolResult","toolCallId":"t\#(number)","toolName":"bash","content":[{"type":"text","text":"\#(output)"}],"isError":false,"timestamp":1758708003000}}"#,
                #"{"type":"message","id":"p\#(base + 3)","parentId":"p\#(base + 2)","timestamp":"2026-09-24T10:00:04.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Fixed. Café ☕️ \#(reply)"}],"stopReason":"stop","timestamp":1758708004000}}"#,
            ]
        }

        /// A prompt continuing the line before it, so the active branch keeps every earlier line. Numbers run from 0 up.
        static func appendedLine(_ number: Int, after lastID: String) -> String {
            let parent = number == 0 ? lastID : "a\(number - 1)"
            return
                #"{"type":"message","id":"a\#(number)","parentId":"\#(parent)","timestamp":"2026-09-24T10:00:05.000Z","message":{"role":"user","content":"Appended \#(number)","timestamp":1758708005000}}"#
        }
    }
}
