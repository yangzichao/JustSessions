# README screenshots

These are unedited JPEG captures of the actual JustSessions SwiftUI interface, built from revision `7439345` on September 29, 2026. A separate local screenshot app supplied sample projects and conversations to the production views and models. The normal app and its saved sessions were not used as screenshot content.

| Image | What it shows |
| --- | --- |
| [session-overview.jpg](session-overview.jpg) | Local projects, CLI labels, pinned sessions, conversation preview, and remote host groups. |
| [remote-desktop-sessions.jpg](remote-desktop-sessions.jpg) | A selected Claude Code conversation under the sample `dev-desktop` SSH host. |
| [tmux-keep-running.jpg](tmux-keep-running.jpg) | The real close-tab confirmation with **Keep running**, **End session**, and **Cancel**. |

`orbit-web`, `orbit-api`, `orbit-infra`, the host names, and all conversation text are illustrative. The remote host data was supplied as a fixture; these images do not document a live SSH connection. The terminal example used a sample process in a separate tmux server, and that process remained running after the screenshot app quit. The example does not run an AI provider or consume model credits.

When replacing these images, capture the current native interface with sample data, retain the real feature labels, and update the source revision above. Keep each screenshot's descriptive alt text and sample-data caption in the [main README](../../README.md).
