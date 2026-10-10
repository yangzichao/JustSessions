import CoreGraphics
import CryptoKit
import Foundation

/// Decodes the images transcripts show, once for every view that shows the same image. Two readers of one session, or
/// a session read again after switching away, read their images into new `Data` from the session file, so an image is
/// known by a digest of its bytes rather than by its `Data`.
///
/// - Views asking for an image that is decoding wait for that decode instead of starting their own.
/// - Decoded images stay in a cache of `cacheByteLimit` pixel bytes, which `NSCache` also empties when memory runs low.
///   A view that shows an image holds it anyway, so the cache costs memory only for images no view shows.
/// - A view that goes away stops waiting. A decode that hasn't started by the time nobody waits for it doesn't start.
///
/// The digest names the bytes, so a cached image can never be an older version of the one asked for.
actor TranscriptImageDecoder {
    static let shared = TranscriptImageDecoder(cacheByteLimit: 128 << 20) { image, maximumPixelSize in
        image.decoded(maximumPixelSize: maximumPixelSize)
    }

    struct Key: Hashable, Sendable {
        let digest: Data
        let maximumPixelSize: Int

        init(_ image: TranscriptImage, maximumPixelSize: Int) {
            digest = Data(SHA256.hash(data: image.data))
            self.maximumPixelSize = maximumPixelSize
        }
    }

    /// A decode under way, and the views waiting for it.
    private struct Decoding {
        let id = UUID()
        var waiters: [UUID: CheckedContinuation<CGImage?, Never>] = [:]
    }

    private let decode: @Sendable (TranscriptImage, Int) -> CGImage?
    private let cache = NSCache<CacheKey, CachedImage>()
    private var decodings: [Key: Decoding] = [:]

    init(cacheByteLimit: Int, decode: @escaping @Sendable (TranscriptImage, Int) -> CGImage?) {
        self.decode = decode
        cache.totalCostLimit = cacheByteLimit
    }

    /// The image decoded for display, downsampled to at most `maximumPixelSize` on its longer side; see
    /// `TranscriptImage.decoded(maximumPixelSize:)`. Nil when the image can't be decoded, or when the calling task is
    /// cancelled first. Digests the image's bytes before it waits its turn on this actor, so digests run in parallel.
    nonisolated func image(for image: TranscriptImage, maximumPixelSize: Int) async -> CGImage? {
        guard !image.data.isEmpty else { return nil }
        let key = Key(image, maximumPixelSize: maximumPixelSize)
        let waiter = UUID()
        return await withTaskCancellationHandler {
            await self.decoded(image, key: key, waiter: waiter)
        } onCancel: {
            Task { await self.stopWaiting(waiter, for: key) }
        }
    }

    private func decoded(_ image: TranscriptImage, key: Key, waiter: UUID) async -> CGImage? {
        if let cached = cache.object(forKey: CacheKey(key)) { return cached.image }
        return await withCheckedContinuation { continuation in
            // Cancellation sets the flag before its handler runs, and the handler's call on this actor waits for this
            // one, so a waiter is either never added or removed by `stopWaiting`.
            guard !Task.isCancelled else { return continuation.resume(returning: nil) }
            if decodings[key] != nil {
                decodings[key]?.waiters[waiter] = continuation
                return
            }
            var decoding = Decoding()
            decoding.waiters[waiter] = continuation
            decodings[key] = decoding
            let decodingID = decoding.id
            let decode = decode
            Task.detached(priority: .userInitiated) {
                guard await self.isWanted(key, decodingID) else { return }
                let decoded = decode(image, key.maximumPixelSize)
                await self.finish(key, decodingID, with: decoded)
            }
        }
    }

    /// Forgets every decoded image, so a measurement can start cold. Decodes under way still finish.
    func removeCachedImages() {
        cache.removeAllObjects()
    }

    private func isWanted(_ key: Key, _ decodingID: UUID) -> Bool {
        decodings[key]?.id == decodingID
    }

    private func finish(_ key: Key, _ decodingID: UUID, with image: CGImage?) {
        if let image {
            cache.setObject(CachedImage(image), forKey: CacheKey(key), cost: image.bytesPerRow * image.height)
        }
        guard let decoding = decodings[key], decoding.id == decodingID else { return }
        decodings[key] = nil
        for continuation in decoding.waiters.values { continuation.resume(returning: image) }
    }

    private func stopWaiting(_ waiter: UUID, for key: Key) {
        guard let continuation = decodings[key]?.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(returning: nil)
        if decodings[key]?.waiters.isEmpty == true { decodings[key] = nil }
    }

    private final class CacheKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? CacheKey)?.key == key }
    }

    private final class CachedImage {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
}
