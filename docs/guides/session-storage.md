# JustSessions session storage and privacy

[Back to JustSessions](../../README.md) · [Session management guide](session-management.md)

JustSessions reads the session files your CLIs already create. It does not upload conversation history to a JustSessions service. When you add an SSH host, its supported session files are copied to a cache on your Mac over SSH. The CLIs you run keep their own network behavior and provider accounts; Sparkle checks GitHub for app updates.

## Session locations

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Yes | Use `/fork` after resuming | Yes |
| Kiro CLI | `~/.kiro/sessions/cli` (honors `KIRO_HOME`) | Yes | Use `/rewind` after resuming | Yes |
| OpenCode | `~/.local/share/opencode/opencode.db`, read-only (honors `OPENCODE_DB` and `XDG_DATA_HOME`) | Not yet | Yes | No |
| Pi | `~/.pi/agent/sessions` (honors `PI_CODING_AGENT_SESSION_DIR`, `sessionDir` in Pi's `settings.json`, and `PI_CODING_AGENT_DIR`) | Yes | Yes | Yes |

Kiro CLI sessions are listed once they have a message; sessions a subagent started are left out. OpenCode subagent sessions and archived sessions are left out too.

Kiro previews show prompts, replies, and collapsed tool calls from the session's `.jsonl` log. Thinking blocks, system context, and raw tool outputs are left out, as in the other supported previews.

Kiro CLI sessions are permanently deleted using its native `kiro-cli chat --delete-session <session-id>` command. Deletion requires an installed Kiro CLI that supports this command; CLI errors are shown without falling back to removing files. See [Kiro's session management documentation](https://kiro.dev/docs/cli/chat/session-management/).

Antigravity previews read visible user messages, agent replies, and tool-call summaries from its SQLite session database. Thinking, injected context, cleared steps, and raw tool output are omitted. On this Mac, deletion moves the database (including WAL companions), the session's `brain/<id>` folder, and its annotation file to the Trash, and removes only its CLI summary-index entry. Files held open by another process cannot be deleted. If moving a file or updating the index fails, moved files and the index are restored. The CLI's last-session shortcut verifies that the selected conversation still exists.

Pi previews follow the branch the session is on now, from its `.jsonl` file: prompts, `!` commands, replies, and collapsed tool calls. Branches left behind with `/tree`, thinking, tool results, and extension messages are left out. On this Mac, deletion moves the session file and the folder beside it, where Pi extensions keep subagent runs and forks, to the Trash; Pi's own delete leaves that folder behind.

## Reading positions

Current source builds keep a session's reading position, including an offset within a long message, in memory for the workspace window's lifetime. Separate reading windows start at the preview's position and keep their own position until they close. Positions are not written to CLI history or persisted across app restarts. Reading a conversation does not launch a CLI or modify the saved session.

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

The mirror uses the standard `~/.claude`, `~/.codex`, `~/.gemini/antigravity-cli`, and `~/.kiro/sessions/cli` locations on the remote host. Custom `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, and `KIRO_HOME` support in the table above applies to this Mac. Kiro mirroring copies only session metadata and transcript files, excluding lock files, prompt history, and nested subagent folders.

Antigravity SSH hosts also need `python3`. SQLite backup snapshots include committed WAL updates; only conversation databases and their summary index are copied, excluding credentials, settings, brain artifacts, and annotations. Temporary snapshots are removed after transfer. Antigravity deletion over SSH additionally needs `lsof` to reject sessions open in another process. It validates the host database's session ID and workspace, stages its database and companions before committing the index change, and then permanently removes them. A failure before commit restores the files and rolls back the index.
