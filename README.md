# claudex-macos

A native macOS launcher for Claude Code and Codex history. Find, resume, and branch existing sessions in their original CLI, now inside an embedded terminal. The app does not re-render transcripts.

## Features

- Scans existing Claude Code and Codex sessions, grouped by project folder with both tools' sessions together and sorted by recent activity.
- Search by display name, project path, or session ID, and filter to sessions active in the past seven days.
- Resume or branch a conversation in an embedded terminal using each CLI's native interactive command.
- Keep multiple terminal tabs open. Returning to the project list leaves their processes running; Resume reopens an already running tab for that conversation. Closing a tab ends its process.
- Rename a row locally. Aliases are saved in this app's UserDefaults and do not change the CLI's own session title.
- Delete a session from its row after confirmation. Claude Code history and its session folder move to the macOS Trash, and its local index entry is removed. Codex uses `codex delete --force`, which permanently deletes the native session.
- Deletion is disabled while that conversation has an open terminal tab in the app.
- Separate adapters make adding another CLI straightforward.

Branch forks the **conversation**. It does not create a Git branch or worktree.

## Build and run

Requires macOS 14+, Xcode Command Line Tools, and whichever CLI you want to use (`claude` and/or `codex`).

```sh
swift test
./Scripts/build-app.sh
open "dist/claudex-macos.app"
```

The app searches `~/.claude/projects` and `~/.codex/sessions`. It honors `CLAUDE_CONFIG_DIR` and `CODEX_HOME` if those variables are present in the app's environment. It reads metadata from Claude's session index and Codex's session index, with fallbacks for unindexed sessions. A session whose original project directory no longer exists remains visible, with launch buttons disabled until the directory is restored.

To start a CLI from Finder, the app checks the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. It launches the CLI directly in a pseudo-terminal with the original project as its working directory. No shell command runs during scanning. The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.

## Source layout

- `Models/`: shared conversation model.
- `Services/Adapters/`: provider discovery and native arguments.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Views/`: SwiftUI project list and embedded terminal tabs.
