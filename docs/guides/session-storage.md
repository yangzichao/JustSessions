# JustSessions session storage and privacy

[Back to JustSessions](../../README.md) · [Session management guide](session-management.md)

JustSessions reads the session files your CLIs already create. It does not upload conversation history to a JustSessions service. When you add an SSH host, its supported session files are copied to a cache on your Mac over SSH. The CLIs you run keep their own network behavior and provider accounts. Sparkle checks for app updates through a JustSessions update server that counts checks per day and app version, without storing IP addresses or identifiers; the downloads come from GitHub Releases. After a crash, JustSessions offers to report it with a GitHub issue or an email filled in from the crash report macOS saved; nothing is sent unless you send it.

## Session locations

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Yes | Use `/fork` after resuming | Yes |
| Kiro CLI | `~/.kiro/sessions/cli` (honors `KIRO_HOME`) | Yes | Use `/rewind` after resuming | Yes |
| OpenCode | `~/.local/share/opencode/opencode.db`, read-only (honors `OPENCODE_DB` and `XDG_DATA_HOME`) | Yes | Yes | Yes |
| Pi | `~/.pi/agent/sessions` (honors `PI_CODING_AGENT_SESSION_DIR`, `sessionDir` in Pi's `settings.json`, and `PI_CODING_AGENT_DIR`) | Yes | Yes | Yes |

Sessions that subagents ran are listed under the session that started them, hidden until you expand it: Claude Code's transcripts in `<session-id>/subagents` beside the session file, Codex threads another thread spawned, OpenCode sessions with a parent, Antigravity conversations whose summary names a parent conversation, and Pi sessions that extensions keep in the folder beside a session file, such as subagent runs and forks. They can be read but not resumed, renamed, pinned, or deleted on their own. Over SSH, only Codex and Antigravity list them; the mirror leaves the other CLIs' subagent files on the host.

Kiro CLI sessions are listed once they have a message. Sessions Kiro marks as started by a subagent are left out, since Kiro doesn't record which session started them. Archived OpenCode sessions are left out.

Kiro previews show prompts, replies, and collapsed tool calls from the session's `.jsonl` log. Thinking blocks, system context, and raw tool outputs are left out, as in the other supported previews.

OpenCode previews read one session out of its database: prompts, replies, and collapsed tool calls, in the order OpenCode shows them. Text OpenCode adds to a prompt, such as the contents of a mentioned file, is left out, and so are reasoning, tool output, and step markers. Attachments a prompt doesn't mention show as `[Image]` or `[File: name]`. After `/undo`, the undone messages are hidden, as in OpenCode, and a note says `/redo` restores them. OpenCode sessions are permanently deleted using its native `opencode session delete <session-id>` command, pointed at the database the session was listed from; it also deletes the session's subagent sessions.

Kiro CLI sessions are permanently deleted using its native `kiro-cli chat --delete-session <session-id>` command. Deletion requires an installed Kiro CLI that supports this command; CLI errors are shown without falling back to removing files. See [Kiro's session management documentation](https://kiro.dev/docs/cli/chat/session-management/).

Antigravity previews read visible user messages, agent replies, and tool-call summaries from its SQLite session database. Thinking, injected context, cleared steps, and raw tool output are omitted. On this Mac, deletion moves the database (including WAL companions), the session's `brain/<id>` folder, and its annotation file to the Trash, and removes only its CLI summary-index entry. Files held open by another process cannot be deleted. If moving a file or updating the index fails, moved files and the index are restored. The CLI's last-session shortcut verifies that the selected conversation still exists.

Pi previews follow the branch the session is on now, from its `.jsonl` file: prompts, `!` commands, replies, and collapsed tool calls. Branches left behind with `/tree`, thinking, tool results, and extension messages are left out. On this Mac, deletion moves the session file and the folder beside it, where Pi extensions keep subagent runs and forks, to the Trash; Pi's own delete leaves that folder behind.

## Reading positions

The app keeps a session's reading position, including an offset within a long message, in memory for the workspace window's lifetime. Separate reading windows start at the preview's position and keep their own position until they close. Positions are not written to CLI history or persisted across app restarts. Reading a conversation does not launch a CLI or modify the saved session.

Reading uses up to three nearby pages, normally about 80 entries per page. Pages also have byte and source-record budgets; all parts of one source record stay together. JSONL readers build a lightweight byte-offset index instead of decoding the entire history. Pi also resolves its active branch from parent links, and Antigravity reads selected step payloads from a consistent SQLite snapshot. A source record above 16 MiB is not decoded for preview; Pi reports an error if such a record prevents correct branch selection. Export continues to use the full transcript loader rather than the page window.

## Message search

Searching message text reads each listed session once, with the same code as the reader, and keeps the text it searches in `~/Library/Caches/dev.zichaoyang.justsessions/SessionMessages`, one file per session. Later searches, after a relaunch too, read again only sessions whose files changed; an SSH host's sessions are read from its local cache. The text of a session that is no longer listed is removed after 30 days. The text leaves memory a minute after the last window closes its search. Nothing is sent anywhere, and the CLIs' files are not changed.

## CLI launch and discovery

The app runs each CLI in a pseudo-terminal with the original project as its working directory, using the CLI's own resume and fork commands. When started from Finder, it combines the inherited `PATH` with the user's login-shell `PATH` and common installation folders, including Homebrew and Node version manager locations. Session discovery reads existing files; app startup also reads the login shell's `PATH`, and tmux integration checks its version and running sessions.

Each refresh also checks which CLIs are installed: on this Mac with the same lookup a launch uses, and on an SSH host with `command -v` in its login shell, in the same SSH call that lists its tmux sessions. New session menus offer only the CLIs found. Until a machine's first check finishes, they offer every CLI that runs there.

Claude Code, Codex, and Antigravity CLI reveal which session a new tab's CLI is writing. Kiro CLI, OpenCode, and Pi don't, so a new tab for one of them takes the first session that appears in its project after the tab started. While such a tab waits, this Mac refreshes about every 6 seconds.

## Terminal persistence

The packaged app contains tmux and its terminal database in `Contents/Resources/Tmux`, with its third-party libraries statically linked. It needs no Homebrew, separate installer, system-directory changes, or runtime download. Direct `swift run` builds use an installed tmux 3.3 or later; without a supported tmux, the CLI runs directly.

The first background refresh checks the available versions. The app prefers its bundled runtime, but uses the installed client when needed to reconnect to an existing JustSessions server, so migration does not restart running work. Each CLI runs in the app's own server (`-L justsessions`), which ignores `~/.tmux.conf` and leaves your other tmux sessions alone. A CLI that exits with an error keeps its tmux pane while its tab is open (`remain-on-exit failed`), so the tab still shows the CLI's output rather than only tmux's `[exited]`; tmux reports the CLI's exit status to the tab, and the session ends once the tab closes or detaches. SSH hosts keep tmux's default, so a failed CLI's output there still disappears with its session. SSH sessions use the host's tmux; the bundled Mac executable is not copied to remote hosts. Their tmux sessions have no prefix key, so every key reaches the CLI. To use the prefix keys from the host's `~/.tmux.conf` in them instead, point at the host's heading, click its **⋯** (or right-click the heading), and choose **Use this host's tmux prefix**; the change reaches the host's running JustSessions sessions at once, and your other tmux sessions keep their own settings either way.

For a bundled server, `"/Applications/JustSessions.app/Contents/Resources/Tmux/bin/tmux" -L justsessions ls` lists its sessions. Use the original installed client for a server started by an older release until those sessions finish. In a tmux tab, dragging selects through tmux and copies to the clipboard when you let go; hold Shift while dragging to select the usual way. Shift-Return still adds a new line in Claude Code.

## Activity indicators

Claude Code reports whether it is working or waiting on you in `~/.claude/sessions`; a Codex session file records when each turn starts and ends. The app reads both about once a second.

## SSH session cache

SSH hosts must accept `ssh <host>` without a password prompt and need `rsync`. Their session files are mirrored into a local cache and read by the same code as this Mac's.

The mirror uses the standard `~/.claude`, `~/.codex`, `~/.gemini/antigravity-cli`, `~/.kiro/sessions/cli`, and `~/.pi/agent/sessions` locations on the remote host. Custom `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `KIRO_HOME`, `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, and Pi `sessionDir` support in the table above applies to this Mac; on a host, Pi sessions saved anywhere else are not listed. Kiro mirroring copies only session metadata and transcript files, excluding lock files, prompt history, and nested subagent folders.

Pi mirroring copies only the session files directly inside each project folder, `<project>/<timestamp>_<session-id>.jsonl`. What Pi extensions keep inside a project folder stays on the host: the folder beside each session with its subagent runs and forks, and `subagent-artifacts`. Deleting a Pi session over SSH is permanent, because SSH hosts have no Trash. It removes the folder beside the session file, then the file, and only within `~/.pi/agent/sessions`. It refuses a session file or project folder that is a symbolic link, and a file whose first line is not that session's header; a symbolically linked folder beside the session is left in place.

OpenCode SSH hosts also need `python3`. The host's login shell decides where its database is, following `OPENCODE_DB` and `XDG_DATA_HOME` as on this Mac. Each refresh builds a temporary snapshot there of the listed sessions only: their messages without tool output, attachments, or reasoning. OpenCode's accounts, credentials, event log, archived sessions, and subagent sessions stay on the host, and the snapshot is removed after transfer. Deleting an OpenCode session over SSH runs `opencode session delete` on the host against that same database.

Antigravity SSH hosts also need `python3`. SQLite backup snapshots include committed WAL updates; only conversation databases and their summary index are copied, excluding credentials, settings, brain artifacts, and annotations. Temporary snapshots are removed after transfer. Antigravity deletion over SSH additionally needs `lsof` to reject sessions open in another process. It validates the host database's session ID and workspace, stages its database and companions before committing the index change, and then permanently removes them. A failure before commit restores the files and rolls back the index.
