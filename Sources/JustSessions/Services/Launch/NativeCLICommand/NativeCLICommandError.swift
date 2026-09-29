import Foundation

enum NativeCLICommandError: LocalizedError {
    case missingExecutable(String)
    case missingProject(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let name):
            "Could not find the \(name) CLI in your shell PATH or common install locations. "
                + "Install it, then check that `\(name)` runs in a new Terminal window."
        case .missingProject(let path): "The project directory no longer exists: \(path)"
        }
    }
}
