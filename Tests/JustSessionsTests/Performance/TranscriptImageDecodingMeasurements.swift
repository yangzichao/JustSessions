import AppKit
import Darwin
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptImageDecodingMeasurements {
    static let imageCount = 24

    @Test func openingImageHeavySessions() async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let encodedImages = try Self.screenshots(count: Self.imageCount).map { $0.base64EncodedString() }
        let label = "\(Self.imageCount) screenshots of 2880×1800 in 240 entries"
        let control = try ImageReaderWindow(transcript: Self.transcript(images: []), offset: 0)
        Self.report("control: the same 240 entries without images", try await Self.measureUntilSettled { control.show() })
        control.close()
        _ = try await Self.measureUntilSettled {}
        for readerCount in [1, 2, 4] {
            await TranscriptImageDecoder.shared.removeCachedImages()
            _ = try await Self.measureUntilSettled {}
            let footprintBeforeOpening = Self.physicalFootprint()
            let readers = try (0..<readerCount).map { index in
                try ImageReaderWindow(transcript: Self.transcript(images: encodedImages), offset: index)
            }
            let opening = try await Self.measureUntilSettled { for reader in readers { reader.show() } }
            Self.report("\(label), \(readerCount) reader(s) opened at once", opening)
            for reader in readers { reader.close() }
            _ = try await Self.measureUntilSettled {}

            let reader = try ImageReaderWindow(transcript: Self.transcript(images: encodedImages), offset: 0)
            let reopening = try await Self.measureUntilSettled { reader.show() }
            Self.report("\(label), reopened after \(readerCount) reader(s) closed", reopening)
            reader.close()
            _ = try await Self.measureUntilSettled {}
            perfReport(
                "\(label), after \(readerCount) reader(s) and the reopened one closed", "memory footprint kept",
                ByteCountFormatter.string(fromByteCount: Self.physicalFootprint() - footprintBeforeOpening, countStyle: .memory))
        }
        #expect(Bool(true))
    }

    struct Settling {
        var time: Duration
        var cpuSeconds: Double
        var longestMainThreadGap: Duration
        var footprintGrowth: Int64
    }

    private static func report(_ scenario: String, _ settling: Settling) {
        perfReport(scenario, "time until settled", settling.time)
        perfReport(scenario, "CPU until settled", String(format: "%.0f ms", settling.cpuSeconds * 1_000))
        perfReport(scenario, "longest main-thread gap", settling.longestMainThreadGap)
        perfReport(
            scenario, "memory footprint growth", ByteCountFormatter.string(fromByteCount: settling.footprintGrowth, countStyle: .memory))
    }

    private static func measureUntilSettled(_ change: () -> Void) async throws -> Settling {
        let footprintBefore = physicalFootprint()
        let heartbeat = MainThreadPerfHeartbeat()
        heartbeat.start()
        let clock = ContinuousClock()
        let start = clock.now
        let cpuStart = processCPUSeconds()
        change()
        var quietSince: ContinuousClock.Instant?
        var lastCPU = processCPUSeconds()
        var lastSample = clock.now
        while clock.now - start < .seconds(20) {
            try await Task.sleep(for: .milliseconds(50))
            let cpu = processCPUSeconds()
            let now = clock.now
            let elapsed = now - lastSample
            let rate = (cpu - lastCPU) / (Double(elapsed.components.attoseconds) / 1e18 + Double(elapsed.components.seconds))
            (lastCPU, lastSample) = (cpu, now)
            if rate < 0.05 {
                let since = quietSince ?? now
                quietSince = since
                if now - since >= .milliseconds(300) { break }
            } else {
                quietSince = nil
            }
        }
        heartbeat.stop()
        let settledAt = quietSince ?? clock.now
        return Settling(
            time: settledAt - start,
            cpuSeconds: processCPUSeconds() - cpuStart,
            longestMainThreadGap: heartbeat.longestGap,
            footprintGrowth: physicalFootprint() - footprintBefore
        )
    }

    private static func transcript(images: [String]) -> TranscriptContent {
        var entries: [TranscriptEntry] = []
        for index in 0..<240 {
            let content: TranscriptEntry.Content
            if index % 10 == 5, !images.isEmpty {
                content = .toolResultImage(TranscriptImage(base64Encoded: images[(index / 10) % images.count]))
            } else if index % 10 == 5 {
                content = .assistantMessage("Reply \(index): no screenshot here.")
            } else if index % 2 == 0 {
                content = .userMessage("Question \(index): does the settings page lay out at this width?")
            } else {
                content = .assistantMessage("Reply \(index): the screenshot shows the layout. It fits, with room to spare.")
            }
            entries.append(TranscriptEntry(id: index, content: content, timestamp: nil, startsTurn: index % 2 == 0))
        }
        return TranscriptContent(entries: entries, omittedEntryCount: 0)
    }

    private static func screenshots(count: Int) throws -> [Data] {
        var generator = SeededRandomNumberGenerator(seed: 62)
        return try (0..<count).map { index in
            let width = 2880
            let height = 1800
            let bitmap = try #require(
                NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
                ))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSColor(white: 0.95, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            NSColor(calibratedHue: CGFloat(index) / CGFloat(count), saturation: 0.3, brightness: 0.9, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 500, height: height).fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28), .foregroundColor: NSColor.black]
            for line in 0..<40 {
                ("Screenshot \(index), line \(line): settings, sidebar, and transcript layout" as NSString)
                    .draw(at: NSPoint(x: 560, y: 40 + line * 42), withAttributes: attributes)
            }
            NSGraphicsContext.restoreGraphicsState()
            let pixels = try #require(bitmap.bitmapData)
            for row in 1_200..<1_600 {
                for column in 100..<500 {
                    let offset = row * bitmap.bytesPerRow + column * 4
                    for channel in 0..<3 { pixels[offset + channel] = UInt8.random(in: 0...255, using: &generator) }
                }
            }
            return try #require(bitmap.representation(using: .png, properties: [:]))
        }
    }

    private static func processCPUSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    private static func physicalFootprint() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int64(info.phys_footprint) : 0
    }
}

@MainActor
private final class ImageReaderWindow {
    private let window: NSWindow
    private let hostingView: NSHostingView<AnyView>
    private let settings: IsolatedUserDefaults

    init(transcript: TranscriptContent, offset: Int) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        let conversation = TranscriptScrollViewFixture.conversation("image-decoding-\(offset)")
        let positionStore = TranscriptReadingPositionStore()
        positionStore.record(.entry(index: 0, offset: 0), for: conversation.id)
        hostingView = NSHostingView(
            rootView: AnyView(
                TranscriptScrollView(conversation: conversation, transcript: transcript, positionStore: positionStore)
                    .defaultAppStorage(settings.userDefaults)
            ))
        window = NSWindow(
            contentRect: NSRect(x: 40 * offset, y: 40 * offset, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
    }

    func show() {
        window.contentView = hostingView
        window.orderFrontRegardless()
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.contentView = nil
        window.close()
        settings.removeSuite()
    }
}
