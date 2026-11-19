import Foundation

struct OKLabColor: Equatable {
    let lightness: Double
    let greenRed: Double
    let blueYellow: Double

    var chroma: Double {
        (greenRed * greenRed + blueYellow * blueYellow).squareRoot()
    }

    init(lightness: Double, greenRed: Double, blueYellow: Double) {
        self.lightness = lightness
        self.greenRed = greenRed
        self.blueYellow = blueYellow
    }

    init(hexValue: UInt32) {
        let red = Self.linearChannel(hexValue >> 16)
        let green = Self.linearChannel(hexValue >> 8)
        let blue = Self.linearChannel(hexValue)
        let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
        let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
        let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
        lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
        greenRed = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
        blueYellow = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
    }

    func withChroma(_ newChroma: Double) -> OKLabColor {
        let currentChroma = chroma
        guard currentChroma > 0 else { return self }
        let scale = newChroma / currentChroma
        return OKLabColor(lightness: lightness, greenRed: greenRed * scale, blueYellow: blueYellow * scale)
    }

    var isInSRGB: Bool {
        linearSRGBChannels.allSatisfy { (-0.0001...1.0001).contains($0) }
    }

    var hexValue: UInt32 {
        linearSRGBChannels.reduce(0) { result, linearChannel in
            let clamped = min(max(linearChannel, 0), 1)
            let encoded = clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
            return result << 8 | UInt32((encoded * 255).rounded())
        }
    }

    private var linearSRGBChannels: [Double] {
        let long = pow(lightness + 0.3963377774 * greenRed + 0.2158037573 * blueYellow, 3)
        let medium = pow(lightness - 0.1055613458 * greenRed - 0.0638541728 * blueYellow, 3)
        let short = pow(lightness - 0.0894841775 * greenRed - 1.2914855480 * blueYellow, 3)
        return [
            4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
            -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
            -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short,
        ]
    }

    private static func linearChannel(_ shiftedHexValue: UInt32) -> Double {
        let encoded = Double(shiftedHexValue & 0xFF) / 255
        return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
    }
}
