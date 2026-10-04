# README screenshots

These are unedited JPEG captures of the actual JustSessions SwiftUI interface. The overview, SSH, and native terminal captures were refreshed on October 4, 2026, using the current production views and models in a separate local screenshot app. The capture build was based on revision `78c924c`, including local sidebar and button styling changes in progress at capture time. The tmux dialog was captured from revision `7439345` on September 29, 2026. The normal app and its saved conversations were not used as screenshot content.

| Image | What it shows |
| --- | --- |
| [session-overview.jpg](session-overview.jpg) | All six CLI icons, pinned sessions, Projects / Open tabs navigation, per-host refresh buttons, and the reading toolbar with Find and Open in new window. |
| [native-terminal.jpg](native-terminal.jpg) | The installed Claude Code CLI's real interactive `/help` screen in the native terminal, with project tab groups, agent icons, and a plain shell tab. |
| [remote-desktop-sessions.jpg](remote-desktop-sessions.jpg) | A selected Claude Code conversation under the sample `dev-desktop` SSH host with the current sidebar and reading controls. |
| [tmux-keep-running.jpg](tmux-keep-running.jpg) | The real close-tab confirmation with **Keep running**, **End session**, and **Cancel**. |

`orbit-web`, `orbit-api`, `orbit-infra`, the host names, and all saved conversation text are illustrative. The remote host data was supplied as a fixture; these images do not document a live SSH connection.

The native terminal screenshot runs the installed Claude Code CLI in the sample project and displays its local help screen. No model prompt was submitted. The other agent-associated tabs use sample shell processes to illustrate navigation; they do not show Codex or Pi model activity. The plain terminal runs a shell in a temporary sample Git project. The older tmux dialog used a sample process in a separate tmux server, which remained running after the screenshot app quit.

When replacing these images, capture the current native interface with sample data, retain the real feature labels, and update the source revision above. The October 4 captures used debug objects from `make check`, excluding the normal app entry point, linked to a temporary sample-data app with background polling disabled. Only the native terminal capture launches Claude Code; none makes an SSH connection. Keep each screenshot's descriptive alt text and sample-data caption in the [main README](../../README.md).
