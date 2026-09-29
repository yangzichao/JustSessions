# JustSessions session storage and privacy

[Back to JustSessions](../../README.md) · [Session management guide](session-management.md)

JustSessions reads the session files your CLIs already create. It does not upload conversation history to a JustSessions service. When you add an SSH host, its supported session files are copied to a cache on your Mac over SSH. The CLIs you run keep their own network behavior and provider accounts; Sparkle checks GitHub for app updates.

## Session locations

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Not yet | Use `/fork` after resuming | No |

## CLI launch and discovery

The app runs each CLI in a pseudo-terminal with the original project as its working directory, using the CLI's own resume and fork commands. When started from Finder, it combines the inherited `PATH` with the user's login-shell `PATH` and common installation folders, including Homebrew and Node version manager locations. Session discovery reads existing files; app startup also reads the login shell's `PATH`, and tmux integration checks its version and running sessions.

## Terminal persistence

With tmux 3.3 or later, each CLI on this Mac runs in the app's own tmux server, which ignores `~/.tmux.conf` and leaves your other tmux sessions alone. `tmux -L justsessions ls` lists its sessions. Without tmux, the CLI runs directly. In a tmux tab, dragging selects through tmux and copies to the clipboard when you let go; hold Shift while dragging to select the usual way. Shift-Return still adds a new line in Claude Code.

## Activity indicators

Claude Code reports whether it is working or waiting on you in `~/.claude/sessions`; a Codex session file records when each turn starts and ends. The app reads both about once a second.

## SSH session cache

SSH hosts must accept `ssh <host>` without a password prompt and need `rsync`. Their session files are mirrored into a local cache and read by the same code as this Mac's.

The mirror uses the standard `~/.claude` and `~/.codex` locations on the remote host. Custom `CLAUDE_CONFIG_DIR` and `CODEX_HOME` support in the table above applies to this Mac.
