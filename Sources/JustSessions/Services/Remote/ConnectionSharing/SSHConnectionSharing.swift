import Darwin
import Foundation

struct SSHConnectionSharing: Sendable {
    static let socketRoot = "/tmp/justsessions-ssh-\(getuid())"
    static let crashFallbackSeconds = 60

    let options: [String]
    private let state: State?

    static func startRefresh(
        to host: String,
        loginConnections: SSHLoginConnections = .shared
    ) -> SSHConnectionSharing? {
        let loginOptions = loginConnections.connectionOptions(for: host)
        if !loginOptions.isEmpty { return SSHConnectionSharing(throughLoginWithOptions: loginOptions) }
        guard let directory = SSHSocketDirectory.makeRefreshDirectory(at: socketRoot) else { return nil }
        let controlPath = directory.appendingPathComponent("master").path
        guard
            let configuration = SSHHostConfiguration.resolveWithConnectionSharingFallback(
                host: host,
                controlPath: controlPath
            ), configuration.controlMaster == "auto", configuration.controlPath == controlPath,
            configuration.controlPersist == String(crashFallbackSeconds)
        else {
            try? FileManager.default.removeItem(at: directory)
            return nil
        }
        return SSHConnectionSharing(host: host, directory: directory, controlPath: controlPath)
    }

    init(
        host: String,
        directory: URL,
        controlPath: String,
        close: (@Sendable (_ host: String, _ controlPath: String) -> Void)? = nil
    ) {
        options = Self.options(controlPath: controlPath)
        state = State(host: host, directory: directory, controlPath: controlPath, close: close ?? Self.close)
    }

    private init(throughLoginWithOptions options: [String]) {
        self.options = options
        state = nil
    }

    static func options(controlPath: String) -> [String] {
        [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=\(crashFallbackSeconds)",
        ]
    }

    func finish() {
        state?.finish()
    }

    private static func close(host: String, controlPath: String) {
        _ = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/ssh",
            arguments: ["-O", "exit", "-S", controlPath, "-o", "BatchMode=yes", "--", host],
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 10
        )
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var isFinished = false
        private let host: String
        private let directory: URL
        private let controlPath: String
        private let close: @Sendable (_ host: String, _ controlPath: String) -> Void

        init(
            host: String,
            directory: URL,
            controlPath: String,
            close: @escaping @Sendable (_ host: String, _ controlPath: String) -> Void
        ) {
            self.host = host
            self.directory = directory
            self.controlPath = controlPath
            self.close = close
        }

        func finish() {
            lock.lock()
            guard !isFinished else {
                lock.unlock()
                return
            }
            isFinished = true
            lock.unlock()

            close(host, controlPath)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
