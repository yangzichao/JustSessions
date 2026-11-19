import CucumberSwift
import Foundation

// CucumberSwift finds the steps through this conformance on its own type.
// swift-format-ignore: AvoidRetroactiveConformances
extension Cucumber: @retroactive StepImplementation {
    public var bundle: Bundle { Bundle.module }

    public func setupSteps() {
        SessionTabSteps.register()
        ClaudeLiveRenameSteps.register()
        CodexThreadSteps.register()
        LiveSessionSteps.register()
        AppendedSessionNameSteps.register()
    }
}
