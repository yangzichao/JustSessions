import SwiftUI

struct TranscriptImageView: View {
    let image: TranscriptImage
    @State private var decodedImage: CGImage?
    @State private var failedToDecode = false

    private static let maximumHeight: CGFloat = 400
    private static let maximumPixelSize = 1_600
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
        .clipShape(RoundedRectangle(.panel))
        .overlay(RoundedRectangle(.panel).stroke(ThemePalette.hairline, lineWidth: 1))
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
                    .font(ThemeFont.callout)
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
