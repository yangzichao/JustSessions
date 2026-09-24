import Foundation

struct CodexSessionFileLocator: Sendable {
    func openSessionFile(for processID: Int32) -> URL? {
        guard processID > 0 else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-Fn", "-p", String(processID)]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return Self.sessionFile(in: text)
        } catch {
            return nil
        }
    }

    static func sessionFile(in lsofOutput: String) -> URL? {
        for line in lsofOutput.split(separator: "\n") where line.hasPrefix("n") {
            let path = String(line.dropFirst())
            let file = URL(fileURLWithPath: path)
            if file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
                return file.standardizedFileURL
            }
        }
        return nil
    }
}
