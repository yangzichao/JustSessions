import Darwin
import Foundation

/// What the kernel says about one process on this Mac.
enum RunningProcessInfo {
    /// Whether the process exists, including one this app may not signal.
    static func isRunning(_ processID: Int32) -> Bool {
        guard processID > 0 else { return false }
        return kill(processID, 0) == 0 || errno == EPERM
    }

    /// When the process started, or nil when it does not run.
    static func startDate(of processID: Int32) -> Date? {
        guard processID > 0 else { return nil }
        var request: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, processID]
        var entry = kinfo_proc()
        var byteCount = MemoryLayout<kinfo_proc>.stride
        // A process that does not exist reads as success with no bytes.
        guard sysctl(&request, u_int(request.count), &entry, &byteCount, nil, 0) == 0, byteCount > 0 else { return nil }
        let startTime = entry.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000)
    }
}
