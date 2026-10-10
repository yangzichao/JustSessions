import CoreGraphics
import Foundation
import Testing
@testable import JustSessions

/// Readers showing the same image share one decode and its result, a view that goes away stops waiting without
/// stopping the others, and an image that can't be decoded is tried again next time.
struct TranscriptImageDecoderTests {
    @Test func viewsAskingForTheSameBytesShareOneDecodeAndItsResult() async throws {
        let counter = DecodeCounter(delay: .milliseconds(200))
        let decoder = TranscriptImageDecoder(cacheByteLimit: 1 << 20, decode: counter.decode)
        // Two readers read the image into their own `Data`.
        let first = TranscriptImage(base64Encoded: SampleTranscriptImage.base64)
        let second = TranscriptImage(base64Encoded: SampleTranscriptImage.base64)

        async let firstImage = decoder.image(for: first, maximumPixelSize: 1_600)
        async let secondImage = decoder.image(for: second, maximumPixelSize: 1_600)
        let (a, b) = await (firstImage, secondImage)

        #expect(counter.count == 1)
        let shared = try #require(a)
        #expect(b === shared)

        let reopened = await decoder.image(for: TranscriptImage(base64Encoded: SampleTranscriptImage.base64), maximumPixelSize: 1_600)
        #expect(counter.count == 1)
        #expect(reopened === shared)

        _ = await decoder.image(for: first, maximumPixelSize: 400)
        #expect(counter.count == 2)
    }

    @Test func aViewThatGoesAwayStopsWaitingAndTheOthersStillGetTheImage() async throws {
        let counter = DecodeCounter(delay: .milliseconds(300))
        let decoder = TranscriptImageDecoder(cacheByteLimit: 1 << 20, decode: counter.decode)
        let image = SampleTranscriptImage.image

        let leaving = Task { await decoder.image(for: image, maximumPixelSize: 1_600) }
        let staying = Task { await decoder.image(for: image, maximumPixelSize: 1_600) }
        try await Task.sleep(for: .milliseconds(50))
        leaving.cancel()

        #expect(await leaving.value == nil)
        #expect(await staying.value != nil)
        #expect(counter.count == 1)
    }

    @Test func anImageThatCantBeDecodedIsTriedAgainNextTime() async {
        let counter = DecodeCounter(delay: .zero, fails: true)
        let decoder = TranscriptImageDecoder(cacheByteLimit: 1 << 20, decode: counter.decode)

        #expect(await decoder.image(for: SampleTranscriptImage.image, maximumPixelSize: 1_600) == nil)
        #expect(await decoder.image(for: SampleTranscriptImage.image, maximumPixelSize: 1_600) == nil)
        #expect(counter.count == 2)
        #expect(await decoder.image(for: TranscriptImage(data: Data()), maximumPixelSize: 1_600) == nil)
        #expect(counter.count == 2)
    }

    @Test func theSharedDecoderDecodesARealImage() async throws {
        let decoded = try #require(await TranscriptImageDecoder.shared.image(for: SampleTranscriptImage.image, maximumPixelSize: 1_600))
        #expect(CGSize(width: decoded.width, height: decoded.height) == SampleTranscriptImage.pixelSize)
    }
}

/// Stands in for ImageIO: counts decodes and makes a new image for each, after `delay`.
private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var decodeCount = 0
    private let delay: Duration
    private let fails: Bool

    init(delay: Duration, fails: Bool = false) {
        self.delay = delay
        self.fails = fails
    }

    var count: Int { lock.withLock { decodeCount } }

    var decode: @Sendable (TranscriptImage, Int) -> CGImage? {
        { [self] _, maximumPixelSize in
            lock.withLock { decodeCount += 1 }
            Thread.sleep(forTimeInterval: Double(delay.components.attoseconds) / 1e18 + Double(delay.components.seconds))
            guard !fails else { return nil }
            let side = min(maximumPixelSize, 4)
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            return context?.makeImage()
        }
    }
}
