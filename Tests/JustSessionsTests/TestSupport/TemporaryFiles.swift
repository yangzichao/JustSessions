import Foundation

func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JustSessionsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Writes `script` to `file` as an executable, standing in for an installed CLI. A stand-in a test gives a time limit
/// is written with `writeTimedStandIn(_:to:)`.
///
/// macOS checks each newly written executable the first time it runs, one file at a time across the Mac, about 160 ms
/// each, and the test waiting holds one of Swift concurrency's shared threads. At the start of a full run that queue
/// was 185 checks long and took 30 seconds. So `file` is a hard link to this run's copy of the script, see
/// `StandInScripts`, and a script many tests use is checked once. A link is the same file to whatever runs or reads
/// it, unlike a symbolic link, which would change the path a CLI is found at. Writing the file again replaces the link
/// rather than changing the copy other tests share.
@discardableResult
func writeExecutableScript(_ script: String, to file: URL) throws -> URL {
    try StandInScripts.shared.link(script, to: file)
    return file
}

/// Writes a `#!/bin/sh` stand-in that a test gives a time limit, and runs it once first, ending at a line added after
/// `#!/bin/sh`, so that run does nothing the test could count.
///
/// macOS checks each newly written executable the first time it runs, see `writeExecutableScript(_:to:)`, and a file
/// that has run once starts in milliseconds. A script no test has run yet can wait seconds in that queue, past the few
/// seconds such a test gives its stand-in, so the run here waits its turn before the test starts timing; once any
/// test has run the script, it takes milliseconds. It must not wait on the main thread: running every stand-in once
/// there held up the main-actor tests, and two of them failed in each run.
@discardableResult
func writeTimedStandIn(_ script: String, to file: URL) throws -> URL {
    dispatchPrecondition(condition: .notOnQueue(.main))
    let shebang = "#!/bin/sh\n"
    precondition(script.hasPrefix(shebang), "A timed stand-in is a #!/bin/sh script")
    try writeExecutableScript(shebang + standInFirstRunExit + script.dropFirst(shebang.count), to: file)
    let process = Process()
    process.executableURL = file
    process.environment = [standInFirstRunVariable: "1"]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let exited = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in exited.signal() }
    try process.run()
    exited.wait()
    return file
}

private let standInFirstRunVariable = "JUSTSESSIONS_TEST_STAND_IN_FIRST_RUN"
private let standInFirstRunExit = "[ -z \"$\(standInFirstRunVariable)\" ] || exit 0\n"
