"""Retain tmux's per-file copyright and license headers in the shipped app."""

from pathlib import Path
import re
import sys


def collect_notices(source_directory: Path, destination: Path):
    notices = {}
    for source_file in sorted(source_directory.rglob("*")):
        if source_file.suffix not in (".c", ".h", ".y"):
            continue
        source_text = source_file.read_text(errors="replace")
        header = re.match(r"(?:\s*/\*.*?\*/)+", source_text, re.DOTALL)
        if header and any(word in header[0].lower() for word in ("copyright", "permission", "redistribution")):
            notices.setdefault(header[0].strip(), []).append(str(source_file.relative_to(source_directory)))
    assert notices, "No tmux source notices found"
    destination.write_text("\n\n".join(f"Files: {', '.join(files)}\n{notice}" for notice, files in notices.items()) + "\n")


if __name__ == "__main__":
    collect_notices(Path(sys.argv[1]), Path(sys.argv[2]))
