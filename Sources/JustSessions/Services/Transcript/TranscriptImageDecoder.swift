import CoreGraphics
import CryptoKit
import Foundation

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

    private struct Decoding {
        let id = UUID()
        var waiters: [UUID: CheckedContinuation<CGImage?, Never>] = [:]
    }

    private let decode: @Sendable (TranscriptImage, Int) -> CGImage?
    private let storage: any TranscriptImageStorage
    private var decodings: [Key: Decoding] = [:]

    init(cacheByteLimit: Int, decode: @escaping @Sendable (TranscriptImage, Int) -> CGImage?) {
        self.init(storage: CachedTranscriptImages(byteLimit: cacheByteLimit), decode: decode)
    }

    init(storage: any TranscriptImageStorage, decode: @escaping @Sendable (TranscriptImage, Int) -> CGImage?) {
        self.decode = decode
        self.storage = storage
    }

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
        if let cached = storage.image(for: key) { return cached }
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

    func removeCachedImages() {
        storage.removeAll()
    }

    func waitingViewCount(for image: TranscriptImage, maximumPixelSize: Int) -> Int {
        decodings[Key(image, maximumPixelSize: maximumPixelSize)]?.waiters.count ?? 0
    }

    private func isWanted(_ key: Key, _ decodingID: UUID) -> Bool {
        decodings[key]?.id == decodingID
    }

    private func finish(_ key: Key, _ decodingID: UUID, with image: CGImage?) {
        if let image {
            storage.store(image, for: key, cost: image.bytesPerRow * image.height)
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
}

protocol TranscriptImageStorage: AnyObject {
    func image(for key: TranscriptImageDecoder.Key) -> CGImage?
    func store(_ image: CGImage, for key: TranscriptImageDecoder.Key, cost: Int)
    func removeAll()
}

private final class CachedTranscriptImages: TranscriptImageStorage {
    private let cache = NSCache<CacheKey, CachedImage>()

    init(byteLimit: Int) {
        cache.totalCostLimit = byteLimit
    }

    func image(for key: TranscriptImageDecoder.Key) -> CGImage? {
        cache.object(forKey: CacheKey(key))?.image
    }

    func store(_ image: CGImage, for key: TranscriptImageDecoder.Key, cost: Int) {
        cache.setObject(CachedImage(image), forKey: CacheKey(key), cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private final class CacheKey: NSObject {
        let key: TranscriptImageDecoder.Key
        init(_ key: TranscriptImageDecoder.Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? CacheKey)?.key == key }
    }

    private final class CachedImage {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
}
