import Foundation
import Observation

@MainActor
@Observable
final class InterfaceSizeStore {
    static let shared = InterfaceSizeStore()

    static let defaultScale = 1.0
    static let scaleRange = 0.9...1.5
    static let scaleStep = 0.1
    static let userDefaultsKey = "interfaceScale"

    private(set) var scale: Double
    @ObservationIgnored private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        scale = Self.validScale(userDefaults.object(forKey: Self.userDefaultsKey) as? Double ?? Self.defaultScale)
    }

    func setScale(_ newScale: Double) {
        let validScale = Self.validScale(newScale)
        guard validScale != scale else { return }
        scale = validScale
        if validScale == Self.defaultScale {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
        } else {
            userDefaults.set(validScale, forKey: Self.userDefaultsKey)
        }
    }

    static func validScale(_ value: Double) -> Double {
        guard value.isFinite else { return defaultScale }
        let clamped = min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
        let steps = ((clamped - scaleRange.lowerBound) / scaleStep).rounded()
        return ((scaleRange.lowerBound + steps * scaleStep) * 100).rounded() / 100
    }
}
