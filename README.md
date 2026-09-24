# coca-codex

A native macOS launcher for Claude Code, Codex, and Google Antigravity CLI. Start new sessions, or find and resume existing ones in their original CLI inside an embedded terminal. Claude Code and Codex sessions can also be branched. The app does not re-render transcripts.

## Features

- Scans existing Claude Code, Codex, and local Antigravity CLI sessions, grouped by project folder and sorted by recent activity.
- Browse projects in a persistent sidebar, then see all supported sessions for one folder in a focused list. The sidebar remains visible beside embedded terminals.
- Drag the divider beside the sidebar to adjust its width while browsing sessions or using a terminal. The app remembers the chosen width.
- Expand a project in the sidebar to see its sessions. Open terminal tabs appear in a dedicated sidebar section and mark their project and session; selecting one switches back to that terminal. Selecting a closed session focuses its row and Resume action in the main list.
- Search sessions by display name, project path, or session ID. Search projects separately by folder name or path in the sidebar, and filter to sessions active in the past seven days.
- Resume a conversation in an embedded terminal using each CLI's native interactive command. Claude Code and Codex also support branching from the session row. In Antigravity CLI, use `/fork` after resuming to branch a conversation.
- Use **New session** from the sidebar to choose Claude Code, Codex, or Antigravity and a project folder, including one with no history. The CLI starts in that folder with no resume or fork arguments. New CLI sessions appear in the project list after returning from the terminal or closing it.
- Use **+** beside a project, or **New session** at the top of its page, to start any supported CLI directly in that project's folder without choosing a path.
- Keep multiple terminal tabs open in a persistent bar above the session list and terminal. Searching or choosing a project switches to the list while the CLI keeps running; click its tab to return. Resume reopens an already running tab for that conversation. Closing a tab ends its process.
- Rename a row locally. Aliases are saved in this app's UserDefaults and do not change the CLI's own session title.
- Delete a Claude Code or Codex session from its row after confirmation. Claude Code history and its session folder move to the macOS Trash, and its local index entry is removed. Codex uses `codex delete --force`, which permanently deletes the native session. Antigravity's deletion flow is interactive in its session picker, so its sessions cannot be deleted from this app.
- Deletion is disabled while that conversation has an open terminal tab in the app.
- Separate adapters make adding another CLI straightforward.
- The app checks for a new GitHub build when it opens and automatically downloads, installs, and reopens it. If a native CLI terminal is running, the update waits for you to close that terminal; **Update** at the bottom of the sidebar checks again at any time.

Branch forks the **conversation**. It does not create a Git branch or worktree.

## Build and run

Requires macOS 14+, Xcode Command Line Tools, and whichever CLI you want to use (`claude`, `codex`, and/or `agy`).

GitHub Actions builds an app archive from every push to `main` and publishes it as a GitHub build release. Updating requires network access and write access to the app folder, but does not need a local source checkout or build tools. The app verifies the downloaded archive's SHA-256 digest, code signature, bundle ID, and source revision before replacing itself. If installation fails, it restores the previous app; details are logged to `~/Library/Logs/coca-codex/update.log`.

```sh
swift test
./Scripts/build-app.sh
open "dist/coca-codex.app"
```

The app searches `~/.claude/projects`, `~/.codex/sessions`, and `~/.gemini/antigravity-cli/conversations`. It honors `CLAUDE_CONFIG_DIR` and `CODEX_HOME` if those variables are present in the app's environment. It reads metadata from Claude's session index, Codex's session index, and Antigravity CLI's local SQLite files, with fallbacks for unindexed sessions. Antigravity IDE-only history without a local CLI conversation database is not listed. A session whose original project directory no longer exists remains visible, with launch buttons disabled until the directory is restored.

To start a CLI from Finder, the app checks the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. It launches the CLI directly in a pseudo-terminal with the original project as its working directory. No shell command runs during scanning. The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.

## Source layout

- `Models/`: shared conversation model.
- `Services/Adapters/`: provider discovery and native arguments.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Views/`: SwiftUI project list and embedded terminal tabs.
