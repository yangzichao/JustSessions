import Foundation
import SwiftTerm

/// SwiftTerm's Metal renderer loads its shaders from `SwiftTerm_SwiftTerm.bundle`, which it looks for beside the main
/// bundle, as `Scripts/build-app.sh` puts it in the app. In a test process the main bundle is the test runner's, so it
/// doesn't find them. This puts the shader library where the renderer also looks: the resources of the bundle SwiftTerm
/// is linked into, which is the test bundle. `TerminalEngineMeasurements` calls it before its Metal case.
enum SwiftTermMetalShaders {
    private static let installed: Bool = {
        guard let rendererClass = NSClassFromString("SwiftTerm.MetalTerminalRenderer") else { return false }
        let bundle = Bundle(for: rendererClass)
        guard let resources = bundle.resourceURL else { return false }
        let target = resources.appendingPathComponent("default.metallib")
        if FileManager.default.fileExists(atPath: target.path) { return true }
        let source = bundle.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("SwiftTerm_SwiftTerm.bundle/Contents/Resources/default.metallib")
        guard FileManager.default.fileExists(atPath: source.path) else { return false }
        do {
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: target)
            return true
        } catch {
            return false
        }
    }()

    @discardableResult
    static func install() -> Bool { installed }
}
