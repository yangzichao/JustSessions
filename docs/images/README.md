# README screenshots

These are unedited JPEG captures of the actual JustSessions SwiftUI and AppKit interface, refreshed on October 4, 2026. The separate sample-data app links the production views and models from revision `d14311dce0af7ac94c3222851cfafb8a383e46f1`. The normal app and its saved conversations were not used as screenshot content.

| Image | What it shows |
| --- | --- |
| [native-terminal.jpg](native-terminal.jpg) | The installed Claude Code CLI's real interactive `/help` screen in the native terminal, with current project tab groups and all six agent icons. |
| [split-terminal.jpg](split-terminal.jpg) | Actual split view: the same Claude Code CLI's command input on the left and a real shell displaying `git diff` in the sample project on the right. |
| [session-overview.jpg](session-overview.jpg) | The current conversation reader, pinned projects and sessions, Projects / Open tabs navigation, per-host refresh, and reading controls. |
| [remote-desktop-sessions.jpg](remote-desktop-sessions.jpg) | A selected Claude Code conversation under the sample `dev-desktop` SSH host. |
| [tmux-keep-running.jpg](tmux-keep-running.jpg) | The current close-tab confirmation with **Keep running**, **End session**, and **Cancel**, shown for an actual sample shell in tmux. |

The main window captures are 2400 × 1440 pixels; the dialog is 520 × 476 pixels. The homepage presents smaller previews beside feature explanations and links to the originals.

`orbit-web`, `orbit-api`, `orbit-infra`, the host names, and all saved conversation text are illustrative. Remote host data is a fixture; these images do not document a live SSH connection.

Claude Code 2.1.289 runs in an isolated sample configuration. Its screenshots show local help and command input; no model prompt was submitted. The split-view shell runs in a temporary sample Git repository with an actual uncommitted change. The tmux screenshot uses a sample shell in a separate server: **Keep running** left that process alive after the screenshot app quit, verified with `tmux list-sessions`, then the sample server was stopped.

The capture app was linked from the debug objects produced by `make check`, excluding the normal app entry point, with fixture data and background polling disabled. When replacing these images, capture the current native interface, retain the real feature labels, update the source revision, and keep each screenshot's descriptive alt text and sample caption in the [main README](../../README.md).
