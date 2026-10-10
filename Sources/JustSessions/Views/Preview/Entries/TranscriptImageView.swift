import SwiftUI

/// Shows an image across the reading column, no taller than a screen's worth. Its shape is reserved from the
/// image's header while it decodes off the main thread, so the entries below it do not move. Every reader showing the
/// same image shares one decode; see `TranscriptImageDecoder`.
struct TranscriptImageView: View {
    let image: TranscriptImage
    @State private var decodedImage: CGImage?
    @State private var failedToDecode = false

    private static let maximumHeight: CGFloat = 400
    /// Twice the readable column, for Retina displays; larger images are downsampled as they decode.
    private static let maximumPixelSize = 1_600
    /// A short strip for an image whose header could not be read, which is unlikely to decode either.
    private static let placeholderAspectRatio: CGFloat = 4

    var body: some View {
        ZStack {
            if let decodedImage {
                Image(decodedImage, scale: 1, label: Text("Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ThemePalette.hairline, lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: Self.maximumHeight, alignment: .leading)
        .task(id: image) { await decode() }
    }

    private var aspectRatio: CGFloat {
        guard let size = image.pixelSize, size.height > 0 else { return Self.placeholderAspectRatio }
        return size.width / size.height
    }

    private var placeholder: some View {
        Group {
            if failedToDecode {
                Label("Image can't be shown", systemImage: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemePalette.secondaryText)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemePalette.raisedSurface)
    }

    private func decode() async {
        let decoded = await TranscriptImageDecoder.shared.image(for: image, maximumPixelSize: Self.maximumPixelSize)
        guard !Task.isCancelled else { return }
        decodedImage = decoded
        failedToDecode = decoded == nil
    }
}
