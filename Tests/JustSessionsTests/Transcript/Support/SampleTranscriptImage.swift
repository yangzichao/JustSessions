import Foundation
@testable import JustSessions

/// A 3 by 2 pixel red PNG, small enough to keep inline in session lines, with sides that differ so a swapped
/// width and height would show.
enum SampleTranscriptImage {
    static let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII="
    static let image = TranscriptImage(base64Encoded: base64)
    static let pixelSize = CGSize(width: 3, height: 2)
}
