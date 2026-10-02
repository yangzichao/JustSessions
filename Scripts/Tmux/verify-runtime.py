"""Check a relocated tmux runtime without Homebrew or the source build tree."""

from pathlib import Path
import os
import pty
import re
import shutil
import subprocess
import sys
import tempfile
import time

# An `nm -m` undefined-symbol line such as `(undefined) weak external _pipe2 (from libSystem)`.
weak_import_pattern = re.compile(r"^\(undefined[^)]*\)\s+(?:\[[^\]]*\]\s+)*weak\s+(?:private\s+)?external\s+(\S+)")


def weak_imports(executable: Path):
    """Return the symbols the executable binds only if the running macOS provides them."""
    symbols = subprocess.check_output(["/usr/bin/nm", "-m", "-u", str(executable)], text=True)
    return sorted({match.group(1) for line in symbols.splitlines() if (match := weak_import_pattern.match(line.strip()))})


def pinned_value(runtime_directory: Path, name: str):
    """Return a value from the runtime's copy of versions.sh."""
    line = next(line for line in (runtime_directory / "versions.txt").read_text().splitlines() if line.startswith(name + "="))
    return line.partition("=")[2]


def minimum_macos_versions(executable: Path):
    """Return the minos of each macOS LC_BUILD_VERSION load command in every architecture."""
    load_commands = subprocess.check_output(["/usr/bin/otool", "-arch", "all", "-l", str(executable)], text=True)
    versions = []
    fields = None
    for line in load_commands.splitlines():
        key, _, value = line.strip().partition(" ")
        if key == "cmd":
            fields = {} if value.strip() == "LC_BUILD_VERSION" else None
        elif fields is not None:
            fields[key] = value.strip()
            if "platform" in fields and "minos" in fields:
                if fields["platform"] in ("1", "MACOS"):
                    versions.append(fields["minos"])
                fields = None
    return versions


def verify_runtime(runtime_directory: Path):
    executable = runtime_directory / "bin/tmux"
    linkage = subprocess.check_output(["/usr/bin/otool", "-L", str(executable)], text=True)
    for line in linkage.splitlines()[1:]:
        dependency = line.strip().split(" (", 1)[0]
        assert dependency.startswith(("/usr/lib/", "/System/Library/")), f"Non-system runtime dependency: {dependency}"
    deployment_target = pinned_value(runtime_directory, "macos_deployment_target")
    minimum_versions = minimum_macos_versions(executable)
    assert minimum_versions and set(minimum_versions) == {deployment_target}, (
        f"Runtime must target macOS {deployment_target}, but its LC_BUILD_VERSION minos is {minimum_versions or 'missing'}"
    )
    # A weak import is an API newer than the deployment target; it is NULL on older macOS and crashes tmux.
    newer_symbols = weak_imports(executable)
    assert not newer_symbols, (
        f"Runtime weakly imports APIs newer than macOS {deployment_target}: {', '.join(newer_symbols)}. "
        "Disable them in the dependency's configure step in Scripts/Tmux/build-helpers.sh."
    )
    for license_name in ("tmux", "libevent", "ncurses", "utf8proc"):
        assert (runtime_directory / f"licenses/{license_name}.txt").stat().st_size > 0
    terminal_names = {entry.name for entry in (runtime_directory / "share/terminfo").rglob("*") if entry.is_file()}
    assert {"xterm-256color", "tmux-256color", "screen-256color"} <= terminal_names, "Missing bundled terminal definitions"
    with tempfile.TemporaryDirectory(prefix="tmux-") as temporary_path:
        root = Path(temporary_path)
        relocated_runtime = root / "App with spaces.app/Contents/Resources/Tmux"
        shutil.copytree(runtime_directory, relocated_runtime)
        environment = {
            "PATH": "/usr/bin:/bin",
            "HOME": temporary_path,
            "TMUX_TMPDIR": temporary_path,
            "TERM": "xterm-256color",
            "TERMINFO_DIRS": f"{relocated_runtime}/share/terminfo:/usr/share/terminfo",
            "LANG": "en_US.UTF-8",
        }
        command = [str(relocated_runtime / "bin/tmux"), "-L", "bundle-check"]

        def run(*arguments):
            return subprocess.check_output(command + list(arguments), env=environment, text=True, stderr=subprocess.STDOUT).strip()

        version = run("-V")
        assert version == "tmux " + pinned_value(runtime_directory, "tmux_version"), "Runtime version differs from the pinned manifest"
        client_processes = []

        def attach_client():
            terminal_master, terminal_slave = pty.openpty()
            client = subprocess.Popen(
                command + ["-f", "/dev/null", "new-session", "-A", "-s", "persistent", "--", "/bin/sleep", "60"],
                env=environment, stdin=terminal_slave, stdout=terminal_slave, stderr=terminal_slave,
            )
            os.close(terminal_slave)
            client_processes.append((client, terminal_master))
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                try:
                    if str(client.pid) in run("list-clients", "-F", "#{client_pid}").splitlines():
                        return client
                except subprocess.CalledProcessError:
                    pass
                assert client.poll() is None, "tmux client exited before attaching"
                time.sleep(0.05)
            raise AssertionError("tmux client did not attach")

        try:
            first_client = attach_client()
            assert run("show-option", "-gv", "default-terminal") == "tmux-256color"
            process_id = int(run("display-message", "-p", "-t", "persistent", "#{pane_pid}"))
            run("detach-client", "-s", "persistent")
            first_client.wait(timeout=5)
            os.kill(process_id, 0)
            assert run("list-sessions", "-F", "#{session_name}") == "persistent"
            second_client = attach_client()
            assert run("display-message", "-p", "-t", "persistent", "#{pane_pid}") == str(process_id)
            run("detach-client", "-s", "persistent")
            second_client.wait(timeout=5)
            print(f"Bundled {version}: system-only linkage, macOS {deployment_target} deployment target without weak imports, licenses, relocation, and process persistence passed.", file=sys.stderr)
        finally:
            subprocess.run(command + ["kill-server"], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for client, terminal_master in client_processes:
                if client.poll() is None:
                    client.terminate()
                client.wait(timeout=5)
                os.close(terminal_master)


if __name__ == "__main__":
    verify_runtime(Path(sys.argv[1]).resolve())
