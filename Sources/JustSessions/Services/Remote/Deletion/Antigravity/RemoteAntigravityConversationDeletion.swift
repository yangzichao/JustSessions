import Foundation

enum RemoteAntigravityConversationDeletion {
    static func command(sessionID: String, projectPath: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "python3 -c " + ShellQuoting.quoted(RemoteAntigravityDeletionMetadata.script + "\n" + script)
                + " " + ShellQuoting.quoted(sessionID) + " " + ShellQuoting.quoted(projectPath)
        )
    }

    private static let script = """
        import pathlib, posixpath, re, shutil, sqlite3, subprocess, sys, tempfile, urllib.parse
        session_id, project_path = sys.argv[1:]
        if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', session_id): raise ValueError('Invalid session ID')
        root = (pathlib.Path.home() / '.gemini/antigravity-cli').resolve()
        source = root / 'conversations' / (session_id + '.db')
        if not source.exists(): sys.exit(3)
        def database_files(path): return [path, pathlib.Path(str(path) + '-wal'), pathlib.Path(str(path) + '-shm')]
        index_path = root / 'conversation_summaries.db'
        candidates = database_files(source) + [root / 'brain' / session_id, root / 'annotations' / (session_id + '.pbtxt')]
        for path in candidates + database_files(index_path):
            if path.resolve() != path: raise ValueError('Unsafe session file path')
        with sqlite3.connect(source.as_uri() + '?mode=ro', uri=True, timeout=2) as database:
            actual_id = database.execute('SELECT cascade_id FROM trajectory_meta LIMIT 1').fetchone()[0]
            metadata = database.execute('SELECT data FROM trajectory_metadata_blob LIMIT 1').fetchone()[0]
            uri = urllib.parse.urlparse(field(field(metadata, 1), 1).decode('utf8'))
            if actual_id != session_id or uri.scheme != 'file' or posixpath.normpath(urllib.parse.unquote(uri.path)) != project_path:
                raise ValueError('The session ID or project changed. Refresh before deleting.')
        database.close()
        files = [path for path in candidates if path.exists()]
        lsof = shutil.which('lsof')
        if lsof is None: raise ValueError('Install lsof on this host before deleting Antigravity sessions.')
        usage = subprocess.run([lsof, '-nP', '-t', '--'] + [str(path) for path in files], capture_output=True, timeout=5)
        if usage.returncode == 0: raise ValueError('This session is open in another process. Close its CLI before deleting it.')
        if usage.returncode != 1 or usage.stdout or usage.stderr: raise ValueError('Could not verify that the session is closed.')
        index = None
        moved = []
        staging = pathlib.Path(tempfile.mkdtemp(prefix='.justsessions-delete-', dir=root))
        try:
            if index_path.exists():
                index = sqlite3.connect(index_path.as_uri() + '?mode=rw', uri=True, timeout=2)
                index.execute('BEGIN IMMEDIATE')
                index.execute("DELETE FROM conversation_summaries WHERE conversation_id = ? AND app_data_dir = 'antigravity-cli'", (session_id,))
            for number, original in enumerate(files):
                staged = staging / str(number)
                original.rename(staged)
                moved.append((original, staged))
            if index is not None: index.commit()
        except BaseException:
            if index is not None: index.rollback()
            for original, staged in reversed(moved):
                if original.exists(): raise ValueError('Session files changed during deletion. Recovery files are in ' + str(staging))
                staged.rename(original)
            shutil.rmtree(staging)
            raise
        finally:
            if index is not None: index.close()
        shutil.rmtree(staging)
        if any(path.exists() for path in candidates): raise ValueError('Session files are still present. Refresh and close its CLI before retrying.')
        """
}
