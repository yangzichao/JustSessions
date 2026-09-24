import AppKit
import UniformTypeIdentifiers

// Renders SVG files to sRGB PNGs with AppKit's built-in SVG support.
// Arguments come in triples: <input.svg> <pixel width> <output.png>.
// Height follows the SVG's aspect ratio.

func renderSVG(at inputPath: String, pixelWidth: Int, to outputPath: String) throws {
    guard let svgImage = NSImage(contentsOf: URL(fileURLWithPath: inputPath)) else {
        throw RenderError.unreadableSVG(inputPath)
    }
    let pixelHeight = Int((Double(pixelWidth) * svgImage.size.height / svgImage.size.width).rounded())
    guard
        let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let bitmapContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw RenderError.bitmapContextUnavailable
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
    svgImage.draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    NSGraphicsContext.restoreGraphicsState()

    guard
        let renderedImage = bitmapContext.makeImage(),
        let pngDestination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: outputPath) as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw RenderError.pngWriteFailed(outputPath)
    }
    CGImageDestinationAddImage(pngDestination, renderedImage, nil)
    guard CGImageDestinationFinalize(pngDestination) else {
        throw RenderError.pngWriteFailed(outputPath)
    }
}

enum RenderError: Error {
    case unreadableSVG(String)
    case bitmapContextUnavailable
    case pngWriteFailed(String)
}

let renderArguments = Array(CommandLine.arguments.dropFirst())
guard !renderArguments.isEmpty, renderArguments.count % 3 == 0 else {
    FileHandle.standardError.write(Data("usage: render-svg-to-png.swift <input.svg> <pixel width> <output.png> ...\n".utf8))
    exit(2)
}

for tripleStart in stride(from: 0, to: renderArguments.count, by: 3) {
    let inputPath = renderArguments[tripleStart]
    let outputPath = renderArguments[tripleStart + 2]
    guard let pixelWidth = Int(renderArguments[tripleStart + 1]), pixelWidth > 0 else {
        FileHandle.standardError.write(Data("invalid pixel width: \(renderArguments[tripleStart + 1])\n".utf8))
        exit(2)
    }
    do {
        try renderSVG(at: inputPath, pixelWidth: pixelWidth, to: outputPath)
    } catch {
        FileHandle.standardError.write(Data("failed to render \(inputPath): \(error)\n".utf8))
        exit(1)
    }
}
