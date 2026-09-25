import Foundation

/// Lists the files that running processes hold open, using one `lsof` call for all of them.
struct ProcessOpenFileReader: Sendable {
    var timeout: TimeInterval = 5

    /// Paths keyed by process id. Processes that have already exited are simply missing.
    func openFilePaths(ofProcessIDs processIDs: [Int32]) -> [Int32: [String]] {
        let validProcessIDs = processIDs.filter { $0 > 0 }
        guard !validProcessIDs.isEmpty,
              let output = BoundedProcessRunner.output(
                  ofExecutable: "/usr/sbin/lsof",
                  arguments: ["-nP", "-w", "-Fn", "-p", validProcessIDs.map(String.init).joined(separator: ",")],
                  timeout: timeout
              ) else { return [:] }
        // lsof exits with status 1 when one of the processes is gone, but still lists the others.
        return Self.openFilePaths(inLsofFieldOutput: output)
    }

    /// Parses `lsof -F` output: a `p<pid>` line starts each process, `n<path>` lines name its files.
    static func openFilePaths(inLsofFieldOutput output: String) -> [Int32: [String]] {
        var pathsByProcessID: [Int32: [String]] = [:]
        var currentProcessID: Int32?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                currentProcessID = Int32(line.dropFirst())
            } else if line.hasPrefix("n"), let currentProcessID {
                pathsByProcessID[currentProcessID, default: []].append(String(line.dropFirst()))
            }
        }
        return pathsByProcessID
    }
}
