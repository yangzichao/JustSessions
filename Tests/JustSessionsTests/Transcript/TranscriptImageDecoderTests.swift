import CoreGraphics
import Foundation
import Testing

@testable import JustSessions

struct TranscriptImageDecoderTests {
    @Test(.oneHeldThreadAtATime) func viewsAskingForTheSameBytesShareOneDecodeAndItsResult() async throws {
        let counter = DecodeCounter(delay: .zero, holdsUntilReleased: true)
        let decoder = TranscriptImageDecoder(storage: ImagesKeptUntilRemoved(), decode: counter.decode)
        let first = TranscriptImage(base64Encoded: SampleTranscriptImage.base64)
        let second = TranscriptImage(base64Encoded: SampleTranscriptImage.base64)

        let firstImage = Task { await decoder.image(for: first, maximumPixelSize: 1_600) }
        let secondImage = Task { await decoder.image(for: second, maximumPixelSize: 1_600) }
        let deadline = ContinuousClock.now + .seconds(120)
        while await decoder.waitingViewCount(for: first, maximumPixelSize: 1_600) < 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await decoder.waitingViewCount(for: first, maximumPixelSize: 1_600) == 2)
        counter.release()
        let (a, b) = (await firstImage.value, await secondImage.value)

        #expect(counter.count == 1)
        let shared = try #require(a)
        #expect(b === shared)

        let reopened = await decoder.image(for: TranscriptImage(base64Encoded: SampleTranscriptImage.base64), maximumPixelSize: 1_600)
        #expect(counter.count == 1)
        #expect(reopened === shared)

        counter.release()
        _ = await decoder.image(for: first, maximumPixelSize: 400)
        #expect(counter.count == 2)
    }

    @Test(.oneHeldThreadAtATime) func aViewThatGoesAwayStopsWaitingAndTheOthersStillGetTheImage() async throws {
        let counter = DecodeCounter(delay: .zero, holdsUntilReleased: true)
        let decoder = TranscriptImageDecoder(cacheByteLimit: 1 << 20, decode: counter.decode)
        let image = SampleTranscriptImage.image

        let leaving = Task { await decoder.image(for: image, maximumPixelSize: 1_600) }
        let staying = Task { await decoder.image(for: image, maximumPixelSize: 1_600) }
        try await expectEventually { counter.count == 1 }
        leaving.cancel()
        let releaseAnyway = Task {
            try await Task.sleep(for: .seconds(5))
            counter.release()
        }
        let leftWith = await leaving.value
        releaseAnyway.cancel()
        counter.release()

        #expect(leftWith == nil)
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

/// Keeps every image until `removeAll()`, so a test of reuse doesn't depend on `NSCache` keeping one.
private final class ImagesKeptUntilRemoved: TranscriptImageStorage {
    private var images: [TranscriptImageDecoder.Key: CGImage] = [:]

    func image(for key: TranscriptImageDecoder.Key) -> CGImage? { images[key] }
    func store(_ image: CGImage, for key: TranscriptImageDecoder.Key, cost: Int) { images[key] = image }
    func removeAll() { images.removeAll() }
}

private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var decodeCount = 0
    private let delay: Duration
    private let fails: Bool
    private let hold: DispatchSemaphore?

    init(delay: Duration, fails: Bool = false, holdsUntilReleased: Bool = false) {
        self.delay = delay
        self.fails = fails
        hold = holdsUntilReleased ? DispatchSemaphore(value: 0) : nil
    }

    var count: Int { lock.withLock { decodeCount } }

    func release() { hold?.signal() }

    var decode: @Sendable (TranscriptImage, Int) -> CGImage? {
        { [self] _, maximumPixelSize in
            lock.withLock { decodeCount += 1 }
            Thread.sleep(forTimeInterval: Double(delay.components.attoseconds) / 1e18 + Double(delay.components.seconds))
            hold?.wait()
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
