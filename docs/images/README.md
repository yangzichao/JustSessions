# README screenshots

These are unedited JPEG captures of the actual JustSessions SwiftUI interface. The overview and SSH captures were refreshed from revision `badb934` on October 2, 2026, using the current production views and models in a separate local screenshot app. The tmux dialog was captured from revision `7439345` on September 29, 2026. The normal app and its saved sessions were not used as screenshot content.

| Image | What it shows |
| --- | --- |
| [session-overview.jpg](session-overview.jpg) | All six CLI icons, pinned sessions, the sidebar's Settings/Help/website controls, and the current reading toolbar with Find and Open in new window. |
| [remote-desktop-sessions.jpg](remote-desktop-sessions.jpg) | A selected Claude Code conversation under the sample `dev-desktop` SSH host with the current sidebar and reading controls. |
| [tmux-keep-running.jpg](tmux-keep-running.jpg) | The real close-tab confirmation with **Keep running**, **End session**, and **Cancel**. |

`orbit-web`, `orbit-api`, `orbit-infra`, the host names, and all conversation text are illustrative. The remote host data was supplied as a fixture; these images do not document a live SSH connection. The terminal example used a sample process in a separate tmux server, and that process remained running after the screenshot app quit. The example does not run an AI provider or consume model credits.

When replacing these images, capture the current native interface with sample data, retain the real feature labels, and update the source revision above. The October captures used the debug objects from `make verify`, excluding the normal app entry point, linked to a temporary sample-data app with background polling disabled. They show reading, without launching a CLI or making an SSH connection. Keep each screenshot's descriptive alt text and sample-data caption in the [main README](../../README.md).
