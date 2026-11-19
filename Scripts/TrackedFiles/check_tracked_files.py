#!/usr/bin/env python3
"""Fails when git tracks a path that must stay out of the repository, such as coding agent skills."""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from forbidden_tracked_paths import find_forbidden_tracked_paths


def list_tracked_paths():
    """Lists the index, so a staged file is caught before it is committed."""
    output = subprocess.run(
        ['git', 'ls-files', '-z', '--cached'],
        check=True, capture_output=True,
    ).stdout
    return [path for path in output.decode('utf-8').split('\0') if path]


def main():
    violations = find_forbidden_tracked_paths(list_tracked_paths())
    if not violations:
        print('Tracked files check passed.')
        return 0
    print('These tracked paths must stay out of git:', file=sys.stderr)
    for tracked_path, reason in violations:
        print(f'  {tracked_path}: {reason}', file=sys.stderr)
    print('Remove them with `git rm --cached <path>`; .gitignore already covers most of them.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
