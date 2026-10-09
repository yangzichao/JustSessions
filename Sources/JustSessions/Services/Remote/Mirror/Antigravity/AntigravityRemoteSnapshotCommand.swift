import Foundation

enum AntigravityRemoteSnapshotCommand {
    static let pathPrefix = "/tmp/justsessions-agy-"
    static let outputHeading = "JUSTSESSIONS_AGY_SNAPSHOT="

    static func create(on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "[ -d \"$HOME/.gemini/antigravity-cli/conversations\" ] || exit 3; python3 -c " + ShellQuoting.quoted(script),
            on: host
        )
    }

    static func snapshotPath(in output: String) -> String? {
        guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix(outputHeading) }) else { return nil }
        let path = String(line.dropFirst(outputHeading.count))
        guard path.hasPrefix(pathPrefix) else { return nil }
        let suffix = path.dropFirst(pathPrefix.count)
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return nil }
        return path
    }

    private static let script = """
        import os, pathlib, re, shutil, sqlite3, tempfile, time
        source = pathlib.Path.home() / '.gemini/antigravity-cli'
        snapshot = pathlib.Path(tempfile.mkdtemp(prefix='justsessions-agy-', dir='/tmp'))
        try:
            (snapshot / 'conversations').mkdir()
            files = list((source / 'conversations').glob('*.db'))
            files = [p for p in files if re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\\.db', p.name)]
            index = source / 'conversation_summaries.db'
            if index.exists(): files.append(index)
            for file in files:
                if file.is_symlink() or not file.is_file(): raise ValueError('Unsafe session database path')
                target = snapshot / file.relative_to(source)
                deadline = time.monotonic() + 10
                def check_progress(status, remaining, total):
                    if time.monotonic() > deadline: raise TimeoutError('Session snapshot timed out')
                with sqlite3.connect(file.as_uri() + '?mode=ro', uri=True, timeout=2) as original:
                    with sqlite3.connect(target) as copied:
                        original.backup(copied, pages=128, progress=check_progress)
                        copied.execute('PRAGMA journal_mode=DELETE')
                timestamp = max(file.stat().st_mtime, pathlib.Path(str(file) + '-wal').stat().st_mtime if pathlib.Path(str(file) + '-wal').exists() else 0)
                os.utime(target, (timestamp, timestamp))
            print('JUSTSESSIONS_AGY_SNAPSHOT=' + str(snapshot))
        except BaseException:
            shutil.rmtree(snapshot)
            raise
        """
}
