import Foundation

/// Tells a tab what an Antigravity CLI on an SSH host does. Antigravity writes that only in the conversation database it
/// keeps open, `~/.gemini/antigravity-cli/conversations/<id>.db`, which the app reads on this Mac (see
/// `AntigravityTurnStateReader`). So a tab's tmux session starts this relay beside the CLI, as Claude Code's and Kiro
/// CLI's (`RemoteClaudeActivityRelay`, `RemoteKiroActivityRelay`). Once a second it finds the conversation database a
/// process at or below its pane holds open, through `/proc/<pid>/fd` on Linux or `lsof` on macOS (from `/usr/sbin` if
/// the `PATH` leaves it out), reads the turn state
/// with the same two queries, and when it changes, sets `workingName`, `waitingName`, or `idleName` as the window option
/// the session's title shows; see `RemoteCLIActivityTitle`. A turn that started before the relay, which starts just
/// before the CLI, was left open by an earlier CLI, so it counts as idle, as on this Mac.
///
/// It runs in the host's `python3`, for its `sqlite3`, which Check this host… looks for for Antigravity; without it the
/// tab tells nothing. Antigravity 1.3.6 on Linux opens a resumed conversation's database as it starts, and a new one's
/// with the first prompt, so a new session tells nothing until then. It ends with the pane's process, and goes on while
/// no tab is attached. `sh` starts it, as the pane's login shell may be fish.
enum RemoteAntigravityActivityRelay {
    static let workingName = "working"
    static let waitingName = "waiting"
    static let idleName = "idle"

    static func activity(named name: String) -> CLIActivity? {
        switch name {
        case workingName: .working
        case waitingName: .needsInput(reason: nil)
        case idleName: .idle
        default: nil
        }
    }

    static let launchCommand =
        "sh -c "
        + ShellQuoting.quoted(#"command -v python3 >/dev/null 2>&1 || exit 0; python3 -c "$1" </dev/null >/dev/null 2>&1 &"#)
        + " sh " + ShellQuoting.quoted(script)

    static let script = #"""
        import os, re, sqlite3, subprocess, time

        OPTION = "\#(RemoteCLIActivityTitle.optionName)"
        WAITING_FOR_APPROVAL = \#(AntigravityTurnStateReader.waitingForApprovalStatus)
        LAST_STEP_INDEX_FIELD = \#(AntigravityTurnStateReader.lastStepIndexField)
        CONVERSATION = re.compile(r"/conversations/[^/]+\.db$")
        STARTED_AT = time.time()

        def run(*args):
            try:
                return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True).stdout
            except OSError:
                return ""

        def varint(data, i):
            value = shift = 0
            while i < len(data):
                byte = data[i]
                i += 1
                value |= (byte & 0x7F) << shift
                shift += 7
                if not byte & 0x80:
                    return value, i
            raise ValueError("cut-off varint")

        def fields(data):
            i = 0
            while i < len(data):
                key, i = varint(data, i)
                number, wire = key >> 3, key & 7
                if wire == 0:
                    value, i = varint(data, i)
                elif wire == 1:
                    value, i = None, i + 8
                elif wire == 2:
                    length, i = varint(data, i)
                    value, i = data[i:i + length], i + length
                elif wire == 5:
                    value, i = None, i + 4
                else:
                    return
                yield number, wire, value

        def integer(data, wanted):
            for number, wire, value in fields(data):
                if number == wanted and wire == 0:
                    return value
            return None

        def message(data, path):
            for wanted in path:
                data = next((value for number, wire, value in fields(data) if number == wanted and wire == 2), None)
                if data is None:
                    return None
            return data

        def started_at(payload):
            timestamp = message(payload or b"", [5, 1])
            if timestamp is None:
                return None
            return (integer(timestamp, 1) or 0) + (integer(timestamp, 2) or 0) / 1e9

        def state(path):
            database = sqlite3.connect("file:" + path + "?mode=ro", uri=True, timeout=1)
            try:
                row = database.execute("SELECT data FROM executor_metadata ORDER BY idx DESC LIMIT 1").fetchone()
                last = -1 if row is None else (integer(row[0] or b"", LAST_STEP_INDEX_FIELD) or 0)
                step = database.execute(
                    "SELECT step_payload, EXISTS (SELECT 1 FROM steps WHERE idx > ? AND status = ?)"
                    " FROM steps WHERE idx > ? ORDER BY idx LIMIT 1",
                    (last, WAITING_FOR_APPROVAL, last)).fetchone()
            finally:
                database.close()
            if step is None:
                return "\#(idleName)"
            first = started_at(step[0])
            if first is not None and first < STARTED_AT:
                return "\#(idleName)"
            return "\#(waitingName)" if step[1] else "\#(workingName)"

        def tree(root):
            children = {}
            for line in run("ps", "-A", "-o", "pid=", "-o", "ppid=").split("\n"):
                pair = line.split()
                if len(pair) == 2:
                    children.setdefault(pair[1], []).append(pair[0])
            found, i = [root], 0
            while i < len(found):
                found.extend(children.get(found[i], []))
                i += 1
            return found

        def open_conversation(pids):
            if os.path.isdir("/proc"):
                for pid in pids:
                    try:
                        descriptors = os.listdir("/proc/%s/fd" % pid)
                    except OSError:
                        continue
                    for descriptor in descriptors:
                        try:
                            path = os.readlink("/proc/%s/fd/%s" % (pid, descriptor))
                        except OSError:
                            continue
                        if CONVERSATION.search(path):
                            return path
                return None
            # macOS keeps lsof in /usr/sbin, which a login shell's PATH may leave out.
            listing = run("lsof", "-Fn", "-p", ",".join(pids)) or run("/usr/sbin/lsof", "-Fn", "-p", ",".join(pids))
            for line in listing.split("\n"):
                if line.startswith("n") and CONVERSATION.search(line[1:]):
                    return line[1:]
            return None

        def alive(pid):
            try:
                os.kill(int(pid), 0)
                return True
            except OSError:
                return False

        pane = os.environ.get("TMUX_PANE", "")
        pane_pid = run("tmux", "display-message", "-p", "-t", pane, "#{pane_pid}").strip()
        shown = None
        while pane and pane_pid and alive(pane_pid):
            path = open_conversation(tree(pane_pid))
            if path:
                try:
                    activity = state(path)
                except Exception:
                    activity = shown
                if activity and activity != shown:
                    run("tmux", "set-option", "-wq", "-t", pane, OPTION, activity + ":", ";", "refresh-client", "-S")
                    shown = activity
            time.sleep(1)
        """#
}
