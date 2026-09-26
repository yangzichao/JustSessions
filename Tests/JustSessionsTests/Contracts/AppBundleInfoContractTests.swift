import Foundation
import Testing
@testable import JustSessions

/// `Scripts/build-app.sh` writes the app's Info.plist from a template. These hold the template to what the code,
/// the package manifest, and Sparkle's update checks expect.
struct AppBundleInfoContractTests {
    @Test func bundleIdentifierIsTheOneTheCodeUses() throws {
        #expect(try Self.infoPlistTemplate()["CFBundleIdentifier"] as? String == AppIdentity.bundleIdentifier)
    }

    @Test func executableIsThePackagesProduct() throws {
        let executableName = try #require(try Self.infoPlistTemplate()["CFBundleExecutable"] as? String)
        let manifest = try RepositoryFiles.contents(of: "Package.swift")
        #expect(manifest.contains(".executable(name: \"\(executableName)\""))
        #expect(try RepositoryFiles.contents(of: "Scripts/build-app.sh").contains(".build/release/\(executableName)\""))
    }

    @Test func minimumSystemVersionMatchesThePackagesPlatform() throws {
        let manifest = try RepositoryFiles.contents(of: "Package.swift")
        let platformMatch = try #require(manifest.firstMatch(of: try Regex(#"\.macOS\(\.v(\d+)(?:_(\d+))?\)"#)))
        let majorVersion = try #require(platformMatch.output[1].substring)
        let minorVersion = platformMatch.output[2].substring ?? "0"

        #expect(try Self.infoPlistTemplate()["LSMinimumSystemVersion"] as? String == "\(majorVersion).\(minorVersion)")
    }

    @Test func iconFileIsInTheRepository() throws {
        let iconName = try #require(try Self.infoPlistTemplate()["CFBundleIconFile"] as? String)
        let iconFile = RepositoryFiles.rootDirectory.appendingPathComponent("Branding/\(iconName).icns")
        #expect(FileManager.default.fileExists(atPath: iconFile.path))
    }

    @Test func updatesAreFetchedOverHTTPSAndVerifiedBeforeInstalling() throws {
        let infoPlist = try Self.infoPlistTemplate()
        let feedURL = try #require((infoPlist["SUFeedURL"] as? String).flatMap(URL.init(string:)))
        let publicKey = try #require((infoPlist["SUPublicEDKey"] as? String).flatMap { Data(base64Encoded: $0) })

        #expect(feedURL.scheme == "https")
        #expect(feedURL.pathExtension == "xml")
        #expect(publicKey.count == 32, "an Ed25519 public key is 32 bytes")
        #expect(infoPlist["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
    }

    /// `plutil -replace` fills in the version at build time; each key it replaces is in the template.
    @Test func everyKeyTheScriptFillsInIsInTheTemplate() throws {
        let script = try RepositoryFiles.contents(of: "Scripts/build-app.sh")
        let replacedKeys = script.matches(of: try Regex(#"plutil -replace (\w+)"#)).compactMap { $0.output[1].substring }
        let infoPlist = try Self.infoPlistTemplate()

        #expect(!replacedKeys.isEmpty)
        for replacedKey in replacedKeys {
            #expect(infoPlist[String(replacedKey)] != nil, "\(replacedKey)")
        }
    }

    /// The property list between `<<'PLIST'` and `PLIST` in the build script.
    private static func infoPlistTemplate() throws -> [String: Any] {
        let script = try RepositoryFiles.contents(of: "Scripts/build-app.sh")
        let templateStart = try #require(script.range(of: "<<'PLIST'\n"))
        let templateEnd = try #require(script.range(of: "\nPLIST\n", range: templateStart.upperBound..<script.endIndex))
        let template = Data(script[templateStart.upperBound..<templateEnd.lowerBound].utf8)
        return try #require(try PropertyListSerialization.propertyList(from: template, format: nil) as? [String: Any])
    }
}
