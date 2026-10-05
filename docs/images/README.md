# README screenshots

These are unedited captures of the actual JustSessions SwiftUI and AppKit interface, refreshed on October 4, 2026. The separate sample-data app links the production views and models from revision `d14311dce0af7ac94c3222851cfafb8a383e46f1`. The normal app and its saved conversations were not used as screenshot content.

| Image | What it shows |
| --- | --- |
| [native-terminal.jpg](native-terminal.jpg) | The installed Claude Code CLI's real interactive `/help` screen with **Projects** selected in the sidebar. The expanded `orbit-web` project lists five new sessions: two Claude Code sessions, Codex, OpenCode, and Pi. Refreshed from the same existing sample app on October 4, 2026. |
| [split-terminal.jpg](split-terminal.jpg) | The selected Open tabs sidebar lists five tabs across two projects: Claude Code, a shell, Codex, OpenCode, and Pi. The split view pairs the real Claude Code CLI's command input with a shell displaying `git diff`. Refreshed from the same existing sample app on October 4, 2026. |
| [session-overview.jpg](session-overview.jpg) | The current conversation reader, pinned projects and sessions, Projects / Open tabs navigation, per-host refresh, and reading controls. |
| [remote-desktop-sessions.jpg](remote-desktop-sessions.jpg) | A selected Claude Code conversation under the sample `dev-desktop` SSH host. |
| [tmux-keep-running.jpg](tmux-keep-running.jpg) | The full app window after quitting and reopening: the same Claude Code CLI reattached in the sample tmux session, with the sidebar, project tabs, and tmux status bar visible. |
| [tmux-close-choice.jpg](tmux-close-choice.jpg) | The actual close-tab dialog for a local tmux session: Keep running, End session, and Cancel. Captured from the same existing sample app on October 4, 2026. |

Full window captures are 2400 × 1440 pixels; the close-tab dialog capture is 520 × 476. The homepage presents full-width screenshots and links to the originals. Its tmux slide pairs the unedited close-tab dialog with the unedited reattached terminal capture in HTML to explain the choice and the result. CSS clips the dialog to its native rounded corners, hiding the gray capture background without adding another frame. These are two separate captures, not one captured window state.

The homepage's first slide overlays [an orange outline](../../website/annotations/project-agents-highlight.svg) around the `orbit-web` project and its five agent sessions, including two Claude Code sessions. The SSH slide uses [the same style of outline](../../website/annotations/ssh-host-highlight.svg) around `DEV-DESKTOP`, its project, and its sessions. These website annotations use each screenshot's original coordinates and scale with it; they are not part of the app UI. The underlying captures and their full-size links remain unedited.

`orbit-web`, `orbit-api`, `orbit-infra`, the host names, and all saved conversation text are illustrative. Remote host data is a fixture; these images do not document a live SSH connection.

Claude Code 2.1.289 runs in an isolated sample configuration. Its screenshots show local help and command input; no model prompt was submitted. The additional tabs in the first and split-view screenshots were opened through the app's New session dialog using the installed CLIs; no model prompts were submitted to them. The split-view shell runs in a temporary sample Git repository with an actual uncommitted change. The tmux screenshot uses Claude Code in a separate sample server. The screenshot app was quit and reopened, then attached to the same running CLI before its local help screen was captured. The sample server was stopped after capture.

The capture app was linked from the debug objects produced by `make check`, excluding the normal app entry point, with fixture data and background polling disabled. When replacing these images, capture the current native interface, retain the real feature labels, update the source revision, and keep each screenshot's descriptive alt text in the [main README](../../README.md). Retain sample-data and capture details here.
