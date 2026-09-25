import Darwin

/// Parent links of the running processes. A tab's own process is not always the CLI itself: an install
/// can be a wrapper script that starts the real CLI as a child, so lookups by process id walk the tree.
struct ProcessTree: Sendable {
    let parentProcessIDs: [Int32: Int32]

    /// `rootProcessID` first, then its children, grandchildren, and so on.
    func processIDs(rootedAt rootProcessID: Int32) -> [Int32] {
        var childProcessIDs: [Int32: [Int32]] = [:]
        for (processID, parentProcessID) in parentProcessIDs where processID != parentProcessID {
            childProcessIDs[parentProcessID, default: []].append(processID)
        }
        var orderedProcessIDs = [rootProcessID]
        var visitedProcessIDs: Set<Int32> = [rootProcessID]
        var nextIndex = 0
        while nextIndex < orderedProcessIDs.count {
            for childProcessID in (childProcessIDs[orderedProcessIDs[nextIndex]] ?? []).sorted()
            where visitedProcessIDs.insert(childProcessID).inserted {
                orderedProcessIDs.append(childProcessID)
            }
            nextIndex += 1
        }
        return orderedProcessIDs
    }

    /// Reads every process in one `sysctl` call. An unreadable table gives an empty tree, which still
    /// answers lookups with just the root process.
    static func ofRunningProcesses() -> ProcessTree {
        var request: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        let entrySize = MemoryLayout<kinfo_proc>.stride
        for _ in 0..<3 {
            var byteCount = 0
            guard sysctl(&request, u_int(request.count), nil, &byteCount, nil, 0) == 0 else { break }
            // Room for processes that start between the size query and the read.
            var entries = [kinfo_proc](repeating: kinfo_proc(), count: byteCount / entrySize + 64)
            byteCount = entries.count * entrySize
            guard sysctl(&request, u_int(request.count), &entries, &byteCount, nil, 0) == 0 else { continue }

            var parentProcessIDs: [Int32: Int32] = [:]
            for entry in entries.prefix(byteCount / entrySize) {
                parentProcessIDs[entry.kp_proc.p_pid] = entry.kp_eproc.e_ppid
            }
            return ProcessTree(parentProcessIDs: parentProcessIDs)
        }
        return ProcessTree(parentProcessIDs: [:])
    }
}
