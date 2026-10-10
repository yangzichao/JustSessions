import Foundation

enum RemoteSSHFolderOpenError: LocalizedError, Equatable {
    case editorCannotOpenSSHFolders
    case didNotFinish
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .editorCannotOpenSSHFolders: "This editor can't open folders on SSH hosts."
        case .didNotFinish: "The editor's command-line tool did not finish."
        case .failed(let output): output.isEmpty ? "The editor's command-line tool failed." : output
        }
    }
}
