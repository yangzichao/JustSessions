import Foundation
import ImageIO

/// An image a message or a tool result carries, as the session file holds it.
struct TranscriptImage: Sendable, Equatable {
    /// The image file's bytes, such as a PNG. Empty when the session file's base64 did not decode.
    let data: Data
    /// Read from the image's header, so the preview can reserve its shape before decoding it. Nil when the data is
    /// not an image ImageIO can read.
    let pixelSize: CGSize?

    init(data: Data) {
        self.data = data
        pixelSize = Self.pixelSize(of: data)
    }

    init(base64Encoded string: String) {
        self.init(data: Data(base64Encoded: string, options: .ignoreUnknownCharacters) ?? Data())
    }

    /// The image decoded for display, downsampled to at most `maximumPixelSize` on its longer side and turned the
    /// way its orientation metadata says. Nil when the data is not an image ImageIO can read.
    func decoded(maximumPixelSize: Int) -> CGImage? {
        guard let source = Self.source(for: data) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func source(for data: Data) -> CGImageSource? {
        data.isEmpty ? nil : CGImageSourceCreateWithData(data as CFData, nil)
    }

    private static func pixelSize(of data: Data) -> CGSize? {
        guard let source = source(for: data),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else { return nil }
        // Orientations 5 to 8 turn the image a quarter turn, so it shows with its sides swapped.
        let isTurned = (properties[kCGImagePropertyOrientation] as? UInt32).map { $0 >= 5 } ?? false
        return isTurned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }
}
