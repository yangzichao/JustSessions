import CucumberSwift
import Foundation

/// SwiftPM links every test target into one bundle, which takes one step implementation; each feature's steps
/// register here. The features are `.feature` files in `Features/`, copied into the bundle as a resource.
extension Cucumber: @retroactive StepImplementation {
    public var bundle: Bundle { Bundle.module }

    public func setupSteps() {
        ClaudeLiveRenameSteps.register()
    }
}
