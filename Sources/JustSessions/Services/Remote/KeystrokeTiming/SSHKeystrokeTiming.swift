import Foundation

/// OpenSSH 9.5 and later send a terminal's keystrokes in batches every 20 ms, and fake ones for a while after typing
/// stops, so someone watching the network can't time each key. That held each keystroke's echo in an SSH tab for about
/// 15 ms more, so tabs, and the Connect… login they go through, whose setting decides for them, turn it off.
/// An `ssh` older than 9.5 refuses the option, as it does any it doesn't know, so it gets none.
enum SSHKeystrokeTiming {
    static let unobscuredOptions = ["-o", "ObscureKeystrokeTiming=no"]

    static let options: [String] = sshAccepts(unobscuredOptions) ? unobscuredOptions : []

    /// `ssh -G` reads the options without connecting. `-F /dev/null` leaves out the user's and the system's
    /// configuration, so nothing there, such as a `Match exec`, runs.
    static func sshAccepts(_ options: [String], sshExecutable: String = "/usr/bin/ssh") -> Bool {
        BoundedProcessRunner.result(
            ofExecutable: sshExecutable,
            arguments: ["-F", "/dev/null", "-G"] + options + ["justsessions-option-check.invalid"],
            timeout: 5
        )?.exitStatus == 0
    }
}
