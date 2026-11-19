import Foundation

enum TerminalSSHFileDropStatus: Equatable {
    case copying(fileName: String, fileNumber: Int, fileCount: Int, fractionCopied: Double)
    case failed(explanation: String)
}
