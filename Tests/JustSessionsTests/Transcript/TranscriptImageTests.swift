import Foundation
import Testing
@testable import JustSessions

struct TranscriptImageTests {
    @Test func readsThePixelSizeFromTheHeaderAndDecodesTheImage() {
        let image = SampleTranscriptImage.image

        #expect(image.pixelSize == SampleTranscriptImage.pixelSize)
        let decoded = image.decoded(maximumPixelSize: 1_600)
        #expect(decoded?.width == 3)
        #expect(decoded?.height == 2)
    }

    @Test func downsamplesToTheMaximumPixelSize() {
        let decoded = SampleTranscriptImage.image.decoded(maximumPixelSize: 2)

        #expect(decoded?.width == 2)
        #expect(decoded?.height == 1)
    }

    /// Session files hold base64 the CLI wrote; text that is not an image still reads as an entry, shown as
    /// unavailable rather than hiding that something was there.
    @Test func dataThatIsNotAnImageHasNoSizeAndDoesNotDecode() {
        let notAnImage = TranscriptImage(base64Encoded: "AAAA")
        let notBase64 = TranscriptImage(base64Encoded: "not base64!")

        #expect(notAnImage.data.count == 3)
        #expect(notAnImage.pixelSize == nil)
        #expect(notAnImage.decoded(maximumPixelSize: 1_600) == nil)
        #expect(notBase64.data.isEmpty)
        #expect(notBase64.pixelSize == nil)
        #expect(notBase64.decoded(maximumPixelSize: 1_600) == nil)
    }
}
