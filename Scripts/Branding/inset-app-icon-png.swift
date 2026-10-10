import AppKit
import UniformTypeIdentifiers

// Places a full-bleed icon render from ictool on the macOS icon grid: an 824px body inset 100px on a 1024px canvas.
// Arguments come in triples: <full-bleed input.png> <pixel width> <output.png>.

let bodyFractionOfCanvas = 824.0 / 1024.0

func insetIcon(at inputPath: String, pixelWidth: Int, to outputPath: String) throws {
    guard
        let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
        let fullBleedImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
        throw InsetError.unreadablePNG(inputPath)
    }
    guard
        let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let bitmapContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelWidth,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw InsetError.bitmapContextUnavailable
    }
    let bodyWidth = Double(pixelWidth) * bodyFractionOfCanvas
    let inset = (Double(pixelWidth) - bodyWidth) / 2
    bitmapContext.interpolationQuality = .high
    bitmapContext.draw(fullBleedImage, in: CGRect(x: inset, y: inset, width: bodyWidth, height: bodyWidth))

    guard
        let insetImage = bitmapContext.makeImage(),
        let pngDestination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: outputPath) as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw InsetError.pngWriteFailed(outputPath)
    }
    CGImageDestinationAddImage(pngDestination, insetImage, nil)
    guard CGImageDestinationFinalize(pngDestination) else {
        throw InsetError.pngWriteFailed(outputPath)
    }
}

enum InsetError: Error {
    case unreadablePNG(String)
    case bitmapContextUnavailable
    case pngWriteFailed(String)
}

let insetArguments = Array(CommandLine.arguments.dropFirst())
guard !insetArguments.isEmpty, insetArguments.count % 3 == 0 else {
    FileHandle.standardError.write(Data("usage: inset-app-icon-png.swift <full-bleed input.png> <pixel width> <output.png> ...\n".utf8))
    exit(2)
}

for tripleStart in stride(from: 0, to: insetArguments.count, by: 3) {
    let inputPath = insetArguments[tripleStart]
    let outputPath = insetArguments[tripleStart + 2]
    guard let pixelWidth = Int(insetArguments[tripleStart + 1]), pixelWidth > 0 else {
        FileHandle.standardError.write(Data("invalid pixel width: \(insetArguments[tripleStart + 1])\n".utf8))
        exit(2)
    }
    do {
        try insetIcon(at: inputPath, pixelWidth: pixelWidth, to: outputPath)
    } catch {
        FileHandle.standardError.write(Data("failed to inset \(inputPath): \(error)\n".utf8))
        exit(1)
    }
}
