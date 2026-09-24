# Conversation Manager for macOS

A small native macOS app for finding local Claude Code and Codex conversations and opening them in their original CLI. It does not render or alter transcripts.

## Features

- Scans existing Claude Code and Codex sessions, grouped by provider and project and sorted by recent activity.
- Search by display name, project path, or session ID, and filter to sessions active in the past seven days.
- Resume or branch a conversation in Terminal.app using each CLI's native interactive command.
- Rename a row locally. Aliases are saved in this app's UserDefaults and do not change the CLI's own session title.
- Separate adapters make adding another CLI straightforward.

Branch forks the **conversation**. It does not create a Git branch or worktree.

## Build and run

Requires macOS 14+, Xcode Command Line Tools, and whichever CLI you want to use (`claude` and/or `codex`).

```sh
swift test
./Scripts/build-app.sh
open "dist/Conversation Manager.app"
```

The app searches `~/.claude/projects` and `~/.codex/sessions`. It honors `CLAUDE_CONFIG_DIR` and `CODEX_HOME` if those variables are present in the app's environment. It reads metadata from Claude's session index and Codex's session index, with fallbacks for unindexed sessions. A session whose original project directory no longer exists remains visible, with launch buttons disabled until the directory is restored.

To start a CLI from Finder, the app checks the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. It creates a short temporary `.command` file and opens it in Terminal.app. No shell command runs during scanning.

## Source layout

- `Models/`: shared conversation model.
- `Services/Adapters/`: provider discovery and native arguments.
- `Services/Launch/`: Terminal handoff and safe shell quoting.
- `Views/`: SwiftUI list and actions.
