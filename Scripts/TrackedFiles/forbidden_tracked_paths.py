"""Paths that must never be committed: coding agents' local state and skills, and machine-local build or tool output."""

from fnmatch import fnmatchcase

# Each rule is (glob matched against every path segment prefix, reason shown to the committer).
FORBIDDEN_PATH_RULES = [
    ('.claude', "coding agent state and skills stay on the contributor's machine"),
    ('.codex', "coding agent state stays on the contributor's machine"),
    ('.cursor', "coding agent state stays on the contributor's machine"),
    ('.agents', "coding agent skills stay on the contributor's machine"),
    ('.gemini', "coding agent state stays on the contributor's machine"),
    ('.windsurf', "coding agent state stays on the contributor's machine"),
    ('.aider*', "coding agent state stays on the contributor's machine"),
    ('CLAUDE.md', 'shared agent instructions live in AGENTS.md'),
    ('CLAUDE.local.md', "personal agent instructions stay on the contributor's machine"),
    ('GEMINI.md', 'shared agent instructions live in AGENTS.md'),
    ('.playwright-mcp', 'browser automation output'),
    ('.wrangler', 'local Wrangler state'),
    ('.dev.vars', 'local Worker secrets'),
    ('.build', 'build output'),
    ('dist', 'build output'),
    ('__pycache__', 'Python bytecode cache'),
    ('.DS_Store', 'Finder metadata'),
    ('*.xcuserstate', 'personal Xcode state'),
    ('*.profraw', 'coverage profile output'),
]


def forbidden_reason(tracked_path):
    """Returns why a repository-relative path must not be tracked, or None when it may be."""
    for segment in tracked_path.split('/'):
        for pattern, reason in FORBIDDEN_PATH_RULES:
            if fnmatchcase(segment, pattern):
                return reason
    return None


def find_forbidden_tracked_paths(tracked_paths):
    """Returns (path, reason) for every tracked path a rule forbids, in input order."""
    violations = []
    for tracked_path in tracked_paths:
        reason = forbidden_reason(tracked_path)
        if reason is not None:
            violations.append((tracked_path, reason))
    return violations
