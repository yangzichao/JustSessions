# Homepage demos

All five clips and their JPEG posters were refreshed on October 10, 2026. Silent H.264 clips use 1600 × 960, 30 fps, `yuv420p`, and `+faststart`. Session management and tmux last 11.6 seconds within their 12-second countdowns; the others last 7.6 seconds within eight-second countdowns.

| Clip | Recorded behavior |
| --- | --- |
| `multi-agent-sessions.mp4` | Switch between real Claude Code, Codex, and OpenCode CLIs. The **Projects** sidebar keeps five sessions under `orbit-web`, including two Claude Code sessions and Pi. |
| `session-reader.mp4` | Select an agent in **New session**, start Claude Code, read a saved conversation, **Resume** it in the CLI, and delete another disposable session into the macOS Trash. |
| `ssh-sessions.mp4` | Read sample conversations under `dev-desktop`, switch to the local Claude CLI, and return to remote history. SSH hosts and cached conversations are fixtures; no live SSH connection is demonstrated. |
| `tmux-persistence.mp4` | Run a Python task in Claude Code's bash mode that hashes 500 disposable files. Close its tab, choose **Keep running**, and click the sidebar session to reattach. The file count advances while the tab is closed. This records tab closure and reattachment, rather than quitting the app. |
| `tabs-split.mp4` | Switch agents and a shell through the six-item vertical **Open tabs** list. Use **Add tab to new split view** to pair Claude Code with the shell, which shows a real Git diff. Reopening tabs at launch is not recorded. |

The isolated sample app links current production views and models from `e8003c06e3151130cb7d7367b6795b8be5432e17`, built with `make check`. See [screenshot provenance](../../docs/images/README.md) for CLI versions and isolation. Native session creation, Resume, Delete, close-tab, and split controls perform the recorded actions. Saved messages and remote hosts are examples. No model response is shown, and the local indexing task is not an AI performance benchmark.

Each clip combines timestamped native captures: 112 for multi-agent, 208 for session management, 102 for SSH, 172 for tmux, and 152 for tabs. Idle gaps between actions are removed, and segment timing is shortened to fit the countdown. Encoding at 30 fps does not synthesize intermediate UI states or alter task output. All frames retain their aspect ratio.

macOS captures sheets separately. Each real sheet is composited over the immediately preceding native window capture. Alert sheets are enlarged to twice their captured resolution for legibility; New session keeps its captured size. Rounded masks remove gray capture corners, with a subtle presentation shadow. No dialog text or controls are recreated. The tmux poster shows the close dialog, the session-management poster shows New session, and the tabs poster shows the finished split. Other posters use the first frame.

The active slide plays its clip; the existing play/pause button controls rotation and media. Returning to a slide restarts it. Only the first clip has HTML autoplay. Clips and posters receive content-hashed URLs. The SSH slide's decorative SVG highlights the remote host header and project outside the app UI.

To refresh a demo, capture a fixed-size native window and record frame timestamps. Encode with FFmpeg's concat input, H.264, no audio, and `+faststart`; keep the clip within its countdown. Update posters, accessible descriptions, social preview, source revision, and SSH highlight coordinates together. Only finished clips and posters are published; raw captures remain in ignored `dist/` folders.
