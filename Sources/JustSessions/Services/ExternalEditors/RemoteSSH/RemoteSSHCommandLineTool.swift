import Foundation

/// The command-line tool inside a VS Code-family app (`Contents/Resources/app/bin/code` in VS Code) that opens a folder
/// on an SSH host. An app qualifies when its `product.json` names a recommended extension for `ssh-remote` folders:
/// when that extension is missing or disabled, the editor itself offers to install or enable it and reload, so this
/// app does not check for it.
enum RemoteSSHCommandLineTool {
    static func find(inApplicationAt applicationURL: URL) -> URL? {
        let appFolder = applicationURL.appendingPathComponent("Contents/Resources/app", isDirectory: true)
        guard
            let productData = try? Data(contentsOf: appFolder.appendingPathComponent("product.json")),
            let product = try? JSONDecoder().decode(Product.self, from: productData),
            product.remoteExtensionTips?["ssh-remote"] != nil,
            !product.applicationName.isEmpty, !product.applicationName.contains("/")
        else { return nil }
        let toolURL = appFolder.appendingPathComponent("bin/\(product.applicationName)")
        return FileManager.default.isExecutableFile(atPath: toolURL.path) ? toolURL : nil
    }

    private struct Product: Decodable {
        let applicationName: String
        let remoteExtensionTips: [String: RemoteExtensionTip]?
    }

    private struct RemoteExtensionTip: Decodable {
        let extensionId: String
    }
}
