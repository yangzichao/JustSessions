import Foundation
import Testing

/// SwiftPM's native build system, which the release workflow's tests use, copies a link among the `.copy` resources
/// as the link itself, and it leads nowhere once it is in the bundle. Swift Build, this Mac's default, follows links,
/// so without this check such a link shows up first in a release run.
struct PackageResourcesContractTests {
    @Test func noCopiedResourceIsOrHoldsALink() throws {
        let manifest = try RepositoryFiles.contents(of: "Package.swift")
        let copiedPaths = manifest.matches(of: try Regex(#"\.copy\("([^"]+)"\)"#))
            .compactMap { $0.output[1].substring.map(String.init) }
        #expect(!copiedPaths.isEmpty)
        for copiedPath in copiedPaths {
            let resource = try #require(
                Self.targetDirectories.lazy
                    .map { RepositoryFiles.rootDirectory.appendingPathComponent($0).appendingPathComponent(copiedPath) }
                    .first { FileManager.default.fileExists(atPath: $0.path) },
                "\(copiedPath) is in no target's folder"
            )
            #expect(Self.links(at: resource).isEmpty, "\(copiedPath)")
        }
    }

    private static let targetDirectories = ["Sources/JustSessions", "Tests/JustSessionsTests"]

    private static func links(at resource: URL) -> [String] {
        var items = [resource]
        if let enumerator = FileManager.default.enumerator(at: resource, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            items += enumerator.compactMap { $0 as? URL }
        }
        return
            items
            .filter { (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true }
            .map(\.path)
    }
}
