# Homepage demos

All five gallery slides use silent H.264 clips at 1600 × 960 and 20 fps, with JPEG posters. Each clip finishes within the gallery's eight-second countdown. No model prompts were submitted.

| Clip | Length | Recorded behavior |
| --- | --- | --- |
| `multi-agent-sessions.mp4` | 7.6 s | Actual sidebar clicks switch between installed Claude Code, Codex, and OpenCode CLIs. Four new sessions, including two Claude Code sessions, stay under `orbit-web`. |
| `session-reader.mp4` | 7.2 s | Jump between first and latest messages, then return to an existing local Claude CLI tab. The second slide presents New / Resume / Delete as a feature set. This clip demonstrates reading and returning to a CLI; it does not demonstrate new-session creation, deletion, searching, or resuming the remote conversation. |
| `ssh-sessions.mp4` | 7.6 s | Expand and collapse the `dev-desktop` project, switch to the local Claude CLI, and return to a remote conversation. The remote hosts and saved history are fixtures; this clip does not establish a live SSH connection. |
| `tmux-persistence.mp4` | 7.6 s | Close a real Claude CLI tab, choose **Keep running**, quit and reopen the sample app, and attach to the same isolated tmux session. The pane PID remained `16002` across the quit and reattach, with zero clients while the app was closed. |
| `tabs-split.mp4` | 7.6 s | Switch tabs in the vertical **Open tabs** list, then choose **Add tab to new split view → Terminal**. The shell shows a real Git diff in the sample repository. This clip does not demonstrate reopening tabs at launch. |

Captured on October 5, 2026 from the existing isolated JustSessions Showcase app described in [screenshot provenance](../../docs/images/README.md), using production views and models from revision `d14311dce0af7ac94c3222851cfafb8a383e46f1`. The app was not rebuilt for this recording. Host and project data are examples. The separate app does not load the user's saved conversations.

The clips combine timestamped captures of actual UI states: 68 for multi-agent, 73 for SSH, 66 for tmux, 59 for tabs, and 27 for reading. Idle gaps are trimmed and longer sequences slightly accelerated to fit the countdown. The tmux clip cuts past app shutdown and startup. Its sample app's **Capture** shortcut attaches to the original tmux session after relaunch; it does not test the normal app's saved-session discovery.

macOS captures the close-tab sheet separately from its parent window. The tmux clip composites that real sheet over the immediately preceding real terminal capture at twice its captured resolution, centered in the window. An antialiased rounded mask removes the sheet capture's gray corners. No dialog text, controls, or CLI output is recreated. The tmux poster uses this composite; the tabs poster uses the resulting split view. Other posters use the first frame. Raw captures and timestamps remain in ignored `dist/` folders rather than published assets.

The existing sample build crashed in `TranscriptSearchTextView.init(frame:textContainer:)` when entering a reader search query during this capture. The reading clip therefore uses message navigation rather than a search demonstration. The app was not rebuilt or changed as part of this website work.

The active slide plays its clip; the existing gallery play/pause button controls both rotation and media. Inactive clips pause, and returning to a slide restarts it. Only the first clip has HTML autoplay, so the remaining clips show their posters until selected. Every clip and poster receives a content-hashed URL. The SSH slide's decorative SVG outlines the host header and project at fixed capture coordinates, outside the app UI.

To replace a clip, capture the same app window at a fixed size, record each frame's timestamp, and encode the sequence with FFmpeg's concat input, H.264, `yuv420p`, no audio, and `+faststart`. Keep the finished clip below eight seconds. Update the poster, accessible description, SSH outline coordinates when applicable, and provenance together. Keep capture files outside the website sources; only finished clips and posters are published.
