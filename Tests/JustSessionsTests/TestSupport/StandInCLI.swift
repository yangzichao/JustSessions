/// A stand-in CLI, `/bin/sleep`, that keeps running for longer than the slowest test that checks it is still running.
/// On the release workflow's busy runner, activity and notification tests took about a minute to reach their checks,
/// after a 30-second stand-in had already exited. Each test ends its tabs or process, which ends the stand-in.
enum StandInCLI {
    static let executablePath = "/bin/sleep"
    static let arguments = ["600"]
}
