import Foundation
import Testing
@testable import JustSessions

struct RemoteSSHCommandLineToolTests {
    private static let productWithSSHTip = """
        {"applicationName": "code", "remoteExtensionTips": {"ssh-remote": {"extensionId": "ms-vscode-remote.remote-ssh"}}}
        """

    @Test func findsTheToolNamedInProductJSON() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let application = try makeApplication(in: directory, product: Self.productWithSSHTip, tool: "code")

        #expect(RemoteSSHCommandLineTool.find(inApplicationAt: application)
            == application.appendingPathComponent("Contents/Resources/app/bin/code"))
    }

    @Test func skipsAnEditorWithoutAnSSHExtensionTip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let product = #"{"applicationName": "code", "remoteExtensionTips": {"wsl": {"extensionId": "ms-vscode-remote.remote-wsl"}}}"#
        let application = try makeApplication(in: directory, product: product, tool: "code")

        #expect(RemoteSSHCommandLineTool.find(inApplicationAt: application) == nil)
    }

    @Test func skipsAnEditorWhoseToolIsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let application = try makeApplication(in: directory, product: Self.productWithSSHTip, tool: nil)

        #expect(RemoteSSHCommandLineTool.find(inApplicationAt: application) == nil)
    }

    @Test func skipsAnAppWithoutProductJSON() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(RemoteSSHCommandLineTool.find(inApplicationAt: directory.appendingPathComponent("Zed.app")) == nil)
    }

    private func makeApplication(in directory: URL, product: String, tool: String?) throws -> URL {
        let application = directory.appendingPathComponent("Editor.app")
        let appFolder = application.appendingPathComponent("Contents/Resources/app")
        try FileManager.default.createDirectory(
            at: appFolder.appendingPathComponent("bin"),
            withIntermediateDirectories: true
        )
        try product.write(to: appFolder.appendingPathComponent("product.json"), atomically: true, encoding: .utf8)
        if let tool {
            try writeExecutableScript("#!/bin/sh\n", to: appFolder.appendingPathComponent("bin/\(tool)"))
        }
        return application
    }
}
