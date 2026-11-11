import Darwin

/// Keeps a descriptor out of the processes the app starts. A terminal tab's process starts with `forkpty` and `execve`,
/// which hand it every open descriptor not marked close-on-exec, and it keeps them until it exits. A socket the app
/// closed then stays open in that process, and the other end doesn't see it close.
enum CloseOnExecDescriptor {
    /// macOS has no `SOCK_CLOEXEC`, so a socket is marked right after it is made.
    static func mark(_ descriptor: Int32) {
        let flags = fcntl(descriptor, F_GETFD)
        if flags >= 0 { _ = fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) }
    }

    /// A copy of `descriptor`, marked as it is made; -1 if it could not be made.
    static func duplicate(_ descriptor: Int32) -> Int32 {
        fcntl(descriptor, F_DUPFD_CLOEXEC, 0)
    }
}
