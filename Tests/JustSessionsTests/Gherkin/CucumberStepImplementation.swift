import CucumberSwift
import Foundation

/// SwiftPM links every test target into one bundle, which takes one step implementation; each feature's steps
/// register here. The features are `.feature` files in `Features/`, copied into the bundle as a resource. Steps match
/// by their text across all features, so steps that read the same are registered once, in `SessionTabSteps`.
extension Cucumber: @retroactive StepImplementation {
    public var bundle: Bundle { Bundle.module }

    public func setupSteps() {
        SessionTabSteps.register()
        ClaudeLiveRenameSteps.register()
        CodexThreadSteps.register()
    }
}
