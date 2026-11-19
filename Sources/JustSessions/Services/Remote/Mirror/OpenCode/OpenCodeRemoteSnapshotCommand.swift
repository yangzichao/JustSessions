import Foundation

enum OpenCodeRemoteSnapshotCommand {
    static let pathPrefix = "/tmp/justsessions-opencode-"
    static let outputHeading = "JUSTSESSIONS_OPENCODE_SNAPSHOT="
    static let noDatabaseExitStatus: Int32 = 3

    static func create(on host: String) -> String {
        let script =
            OpenCodeRemoteDatabaseLocation.shellAssignment(to: "db") + """

                [ -f "$db" ] || exit \(noDatabaseExitStatus)
                exec python3 -c \(ShellQuoting.quoted(pythonScript)) "$db"
                """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    static func snapshotPath(in output: String) -> String? {
        guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix(outputHeading) }) else { return nil }
        let path = String(line.dropFirst(outputHeading.count))
        guard path.hasPrefix(pathPrefix) else { return nil }
        let suffix = path.dropFirst(pathPrefix.count)
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            return nil
        }
        return path
    }

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
            for step in steps:
                try:
                    copy.execute(step['statement'])
                except sqlite3.OperationalError as error:
                    if 'fallbackWhenSomethingIsMissing' not in step or 'no such' not in str(error): raise
                    copy.execute(step['fallbackWhenSomethingIsMissing'])
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
