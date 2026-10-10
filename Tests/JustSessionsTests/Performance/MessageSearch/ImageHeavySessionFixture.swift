import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import JustSessions

/// Generated Claude and Codex sessions in which each user message attaches one PNG, as a screenshot is attached, and
/// gets a reply. Without an image, the same conversation is text only.
enum ImageHeavySessionFixture {
    static func write(
        provider: ConversationProvider, messageCount: Int, imageBase64: String?, in directory: URL
    ) throws -> URL {
        var lines: [String] = []
        for message in 0..<messageCount {
            let question = "Screenshot \(message): what changed on this page?"
            let reply = "Reply \(message): the save button moved below the form."
            switch provider {
            case .claude:
                let image = imageBase64.map { #",{"type":"image","source":{"type":"base64","media_type":"image/png","data":""# + $0 + #""}}"# } ?? ""
                lines.append(#"{"type":"user","timestamp":"2026-10-09T10:00:00.000Z","message":{"role":"user","content":[{"type":"text","text":""# + question + #""}"# + image + "]}}")
                lines.append(#"{"type":"assistant","timestamp":"2026-10-09T10:00:01.000Z","message":{"role":"assistant","content":""# + reply + #""}}"#)
            case .codex:
                let image = imageBase64.map { #",{"type":"input_image","image_url":"data:image/png;base64,"# + $0 + #""}"# } ?? ""
                lines.append(#"{"timestamp":"2026-10-09T10:00:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":""# + question + #""}"# + image + "]}}")
                lines.append(#"{"timestamp":"2026-10-09T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":""# + reply + #""}]}}"#)
            default:
                preconditionFailure("No generated session for \(provider)")
            }
        }
        let file = directory.appendingPathComponent("\(provider.rawValue)-\(imageBase64?.count ?? 0).jsonl")
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
        return file
    }

    /// A PNG of random pixels, which do not compress, so its base64 is about `length` characters.
    static func noisePNGBase64(length: Int) -> String {
        let side = Int((Double(length) / 4).squareRoot()) // 3 bytes a pixel, and base64 takes 4 characters for 3 bytes.
        var pixels = (0..<side * side * 4).map { $0 % 4 == 3 ? 255 : UInt8.random(in: 0...255) }
        let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let png = NSMutableData()
        let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return (png as Data).base64EncodedString()
    }
}
