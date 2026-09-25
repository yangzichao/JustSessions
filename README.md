# JustSessions

A native macOS launcher for Claude Code, Codex, and Google Antigravity CLI. Start new sessions, or find and resume existing ones in their original CLI inside an embedded terminal. Claude Code and Codex sessions can also be branched. Selecting a session shows a read-only preview of its conversation; to continue it, resume it in its CLI.

## Features

- Scans existing Claude Code, Codex, and local Antigravity CLI sessions, grouped by project folder and sorted by recent activity.
- Browse projects and their sessions in a persistent sidebar. The sidebar remains visible beside the conversation preview and embedded terminals.
- Drag the divider beside the sidebar to adjust its width while browsing sessions or using a terminal. The app remembers the chosen width.
- Expand a project in the sidebar to see its sessions. Open terminal tabs appear in a dedicated sidebar section and mark their project and session; selecting one switches back to that terminal. Selecting a session without an open terminal shows its conversation on the right. Each session row shows how long ago it was last active, or its terminal's status while one is open.
- The conversation preview reads Claude Code and Codex session files directly. It shows your messages and the CLI's replies, with runs of tool calls collapsed into one expandable row; thinking and tool output are left out. Very long sessions show their newest 2,000 entries. Antigravity sessions have no preview yet.
- Search in the sidebar filters projects by name or path, and sessions by title or session ID; projects with matches expand while searching. **Recent**, under the search field, limits the sidebar to sessions active in the past seven days, and the filter button beside it to one CLI.
- Resume a conversation in an embedded terminal using each CLI's native interactive command: use **Resume** in the preview header, double-click the session in the sidebar, or use its right-click menu. Claude Code and Codex can also be branched from the preview header or the right-click menu. In Antigravity CLI, use `/fork` after resuming to branch a conversation.
- Use **New session** from the sidebar to choose Claude Code, Codex, or Antigravity and a project folder, including one with no history. The CLI starts in that folder with no resume or fork arguments. The new session appears under its project right away, in italics until the CLI saves it. A Claude Code or Codex tab then switches to the saved session's row, which takes the first prompt as its title. This also works when the CLI is installed through a wrapper script that starts the real CLI as a child process. When the installed `claude` lists `--session-id` in its `--help`, which the app checks once per app launch, a new Claude Code session starts with an id chosen by the app so its tab and row are matched exactly.
- Hover over a project and use **+**, which replaces its session count, to start any supported CLI directly in that project's folder without choosing a path.
- Keep multiple terminal tabs open in a persistent bar above the preview and terminal. **Preview** switches back to the conversation preview while the CLI keeps running; click its tab to return. Resume reopens an already running tab for that conversation. Closing a tab ends its process.
- Drag across terminal output to select text, then press **⌘C** or use **Copy selection**. Terminal colors follow the macOS appearance. Mouse clicks always go to the CLI when it asks for them; hold Shift while dragging to select text in that case.
- Rename a row locally. Aliases are saved in this app's UserDefaults and do not change the CLI's own session title.
- A name set with `/rename` inside a running Claude Code tab appears in that tab's title and its sidebar row within about a second. A local alias still takes priority.
- Right-click a session in the sidebar to resume, branch, rename, copy its ID, reveal its file in Finder, or delete it. Right-click a project to start a session, open or copy its folder path, or delete its eligible sessions after a confirmation. Open terminal sessions and Antigravity sessions are skipped by project deletion.
- Right-click a project or session to pin it. Pinned projects stay at the top of the project list, and pinned sessions stay at the top of their project. Pins are saved in this app's UserDefaults.
- ⌘-click sessions in the sidebar to select several, or ⇧-click to select a range. Right-click any selected row to resume or branch them all, each in its own terminal tab, or to delete them together after a confirmation. The bar at the bottom of the sidebar also offers delete. Selections can span projects; open terminal sessions and Antigravity sessions are skipped.
- Delete a Claude Code or Codex session from its right-click menu or the preview's ⋯ menu after confirmation. Claude Code history and its session folder move to the macOS Trash, and its local index entry is removed. Codex uses `codex delete --force`, which permanently deletes the native session. Antigravity's deletion flow is interactive in its session picker, so its sessions cannot be deleted from this app.
- Deletion is disabled while that conversation has an open terminal tab in the app.
- Separate adapters make adding another CLI straightforward.
- Sparkle checks for updates automatically and presents available updates using its standard macOS update dialog. **Update** at the bottom of the sidebar checks immediately.

Branch forks the **conversation**. It does not create a Git branch or worktree.

## Install

Download `JustSessions.dmg` from the [latest release](https://github.com/yangzichao/JustSessions/releases/latest), open it, and drag **JustSessions** into **Applications**. Launch it from Applications so Sparkle can replace the app in place when an update arrives.

## Build and run

Requires macOS 14+, Xcode Command Line Tools, and whichever CLI you want to use (`claude`, `codex`, and/or `agy`).

Pushes to `main` and pull requests only run `swift test`. GitHub Actions builds, Developer ID signs, notarizes, and publishes the app only when a version tag is pushed; the tag sets the app version:

```sh
git tag v0.17.0
git push origin v0.17.0
```

Each release is attached to its version tag and includes the notarized `JustSessions.dmg` installer, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` that updates use. CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.

```sh
swift test
./Scripts/build-app.sh
open "dist/JustSessions.app"
```

The app searches `~/.claude/projects`, `~/.codex/sessions`, and `~/.gemini/antigravity-cli/conversations`. It honors `CLAUDE_CONFIG_DIR` and `CODEX_HOME` if those variables are present in the app's environment. It reads metadata from Claude's session index, Codex's session index, and Antigravity CLI's local SQLite files, with fallbacks for unindexed sessions. Antigravity IDE-only history without a local CLI conversation database is not listed. A session whose original project directory no longer exists remains visible, with launch buttons disabled until the directory is restored.

To start a CLI from Finder, the app checks the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. It launches the CLI directly in a pseudo-terminal with the original project as its working directory. No shell command runs during scanning. The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.

## Source layout

- `Models/`: shared conversation model.
- `Services/Adapters/`: provider discovery and native arguments.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Services/Terminal/NewSessionDiscovery/`: finds the session a new tab's CLI is writing and links the tab to it.
- `Services/Processes/`: process tree, open files, and short helper processes with a timeout.
- `Services/Transcript/`: read-only conversation readers for the preview.
- `Views/Browser/`: sidebar, terminal tab bar, and window layout.
- `Views/Browser/Sidebar/`: sidebar header, filters, section headings, and session rows.
- `Views/Branding/`: the app mark drawn in the sidebar header.
- `Views/Preview/`: conversation preview for the selected session.
