# JustSessions session storage and privacy

[Back to JustSessions](../../README.md) · [Session management guide](session-management.md)

JustSessions reads the session files your CLIs already create. It does not upload conversation history to a JustSessions service. When you add an SSH host, its supported session files are copied to a cache on your Mac over SSH. The CLIs you run keep their own network behavior and provider accounts; Sparkle checks GitHub for app updates.

## Session locations

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Not yet | Use `/fork` after resuming | No |
| Kiro CLI | `~/.kiro/sessions/cli` (honors `KIRO_HOME`) | Yes | Use `/rewind` after resuming | Yes |
| OpenCode | `~/.local/share/opencode/opencode.db`, read-only (honors `OPENCODE_DB` and `XDG_DATA_HOME`) | Not yet | Yes | No |
| Pi | `~/.pi/agent/sessions` (honors `PI_CODING_AGENT_SESSION_DIR`, `sessionDir` in Pi's `settings.json`, and `PI_CODING_AGENT_DIR`) | Not yet | Yes | No |

Kiro CLI sessions are listed once they have a message; sessions a subagent started are left out. OpenCode subagent sessions and archived sessions are left out too.

Kiro previews show prompts, replies, and collapsed tool calls from the session's `.jsonl` log. Thinking blocks, system context, and raw tool outputs are left out, as in the other supported previews.

Kiro CLI sessions are permanently deleted using its native `kiro-cli chat --delete-session <session-id>` command. Deletion requires an installed Kiro CLI that supports this command; CLI errors are shown without falling back to removing files. See [Kiro's session management documentation](https://kiro.dev/docs/cli/chat/session-management/).

## CLI launch and discovery

The app runs each CLI in a pseudo-terminal with the original project as its working directory, using the CLI's own resume and fork commands. When started from Finder, it combines the inherited `PATH` with the user's login-shell `PATH` and common installation folders, including Homebrew and Node version manager locations. Session discovery reads existing files; app startup also reads the login shell's `PATH`, and tmux integration checks its version and running sessions.

Each refresh also checks which CLIs are installed: on this Mac with the same lookup a launch uses, and on an SSH host with `command -v` in its login shell, in the same SSH call that lists its tmux sessions. New session menus offer only the CLIs found. Until a machine's first check finishes, they offer every CLI that runs there.

Claude Code, Codex, and Antigravity CLI reveal which session a new tab's CLI is writing. Kiro CLI, OpenCode, and Pi don't, so a new tab for one of them takes the first session that appears in its project after the tab started. While such a tab waits, this Mac refreshes about every 6 seconds.

## Terminal persistence

With tmux 3.3 or later, each CLI on this Mac runs in the app's own tmux server, which ignores `~/.tmux.conf` and leaves your other tmux sessions alone. `tmux -L justsessions ls` lists its sessions. Without tmux, the CLI runs directly. In a tmux tab, dragging selects through tmux and copies to the clipboard when you let go; hold Shift while dragging to select the usual way. Shift-Return still adds a new line in Claude Code.

## Activity indicators

Claude Code reports whether it is working or waiting on you in `~/.claude/sessions`; a Codex session file records when each turn starts and ends. The app reads both about once a second.

## SSH session cache

SSH hosts must accept `ssh <host>` without a password prompt and need `rsync`. Their session files are mirrored into a local cache and read by the same code as this Mac's.

The mirror uses the standard `~/.claude`, `~/.codex`, and `~/.kiro/sessions/cli` locations on the remote host. Custom `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, and `KIRO_HOME` support in the table above applies to this Mac. Kiro mirroring copies only session metadata and transcript files, excluding lock files, prompt history, and nested subagent folders.
