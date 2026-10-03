import Foundation

/// Builds the host's OpenCode mirror database in a private folder under `/tmp`, for `rsync` to copy. A host
/// without an OpenCode database exits with 3 before python3 is needed.
enum OpenCodeRemoteSnapshotCommand {
    static let pathPrefix = "/tmp/justsessions-opencode-"
    static let outputHeading = "JUSTSESSIONS_OPENCODE_SNAPSHOT="
    static let noDatabaseExitStatus: Int32 = 3

    static var create: String {
        let script = OpenCodeRemoteDatabaseLocation.shellAssignment + """

            [ -f "$db" ] || exit \(noDatabaseExitStatus)
            exec python3 -c \(ShellQuoting.quoted(pythonScript)) "$db"
            """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))")
    }

    static func snapshotPath(in output: String) -> String? {
        guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix(outputHeading) }) else { return nil }
        let path = String(line.dropFirst(outputHeading.count))
        guard path.hasPrefix(pathPrefix) else { return nil }
        let suffix = path.dropFirst(pathPrefix.count)
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return nil }
        return path
    }

    /// Runs `OpenCodeMirrorSnapshotSteps` with OpenCode's database attached read-only. A step's next statement is
    /// tried only when the database or SQLite lacks a column or function the previous one needs.
    static var pythonScript: String {
        """
        import pathlib, shutil, sqlite3, sys, tempfile
        source = pathlib.Path(sys.argv[1])
        steps = \(OpenCodeMirrorSnapshotSteps.json)
        snapshot = pathlib.Path(tempfile.mkdtemp(prefix='justsessions-opencode-', dir='/tmp'))
        try:
            target = snapshot / 'opencode.db'
            copy = sqlite3.connect(str(target), uri=True, timeout=5, isolation_level=None)
            copy.execute('ATTACH DATABASE ? AS source', (source.as_uri() + '?mode=ro',))
            copy.execute('BEGIN')
            for alternatives in steps:
                for index, statement in enumerate(alternatives):
                    try:
                        copy.execute(statement)
                        break
                    except sqlite3.OperationalError as error:
                        if index == len(alternatives) - 1 or 'no such' not in str(error): raise
            copy.execute('COMMIT')
            copy.execute('DETACH DATABASE source')
            copy.close()
            print('\(outputHeading)' + str(snapshot))
        except BaseException:
            shutil.rmtree(str(snapshot), ignore_errors=True)
            raise
        """
    }
}
