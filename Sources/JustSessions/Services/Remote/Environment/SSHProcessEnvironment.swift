import Foundation

/// The environment every `ssh` and `rsync` the app starts runs with: the user's login shell's, as in Terminal. An app
/// opened from Finder misses what shell rc files set up, so `ssh` there would not find the `SSH_AUTH_SOCK` of
/// 1Password or Secretive, or a `ProxyCommand`'s tool in `/opt/homebrew/bin`, and fail where Terminal works.
enum SSHProcessEnvironment {
    static var standard: [String: String] {
        merged(inherited: ProcessInfo.processInfo.environment, loginShell: LoginShellEnvironment.cachedVariables)
    }

    static func merged(inherited: [String: String], loginShell: [String: String]) -> [String: String] {
        inherited.merging(loginShell.filter { !shellOwnVariables.contains($0.key) }) { _, loginShellValue in
            loginShellValue
        }
    }

    static let shellOwnVariables: Set<String> = ["PWD", "OLDPWD", "SHLVL", "_"]
}
