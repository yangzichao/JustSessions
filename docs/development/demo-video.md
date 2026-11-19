# Demo video

The homepage's narrated demo, `website/media/justsessions-demo.mp4`, is recorded from the real app and edited by scripts in `Scripts/DemoVideo/`. One command runs every step:

```sh
Scripts/DemoVideo/demo-video help
```

[Media provenance](../../website/media/README.md) says what the published video shows and how it was made.

## What it needs

- A main display at least 1664 × 1050 points. The recording stage is the rectangle from (64, 150) to (1664, 1050) in points, captured at 2x and 60 fps.
- Accessibility and Screen Recording permission for the terminal you run the commands from, in **System Settings → Privacy & Security**. The driver finds controls through Accessibility and posts mouse and keyboard events; the recorder uses ScreenCaptureKit.
- The Xcode command-line tools (`swiftc`, `clang`), `ffmpeg`, and `uv`.
- Claude Code, Codex, OpenCode, and Pi on this Mac, in `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`. None of them needs to be signed in: Claude Code only shows saved conversations, and the others talk to a canned local model server.
- The SSH test VM from [SSH development testing](ssh-testing.md), with the `justsessions-test` alias working in batch mode and real Claude Code installed for its `ubuntu` user.
- GarageBand's Chillwave pack of Apple Loops, in `/Library/Audio/Apple Loops/Apple/07 Chillwave`. Download it from GarageBand's Sound Library.
- A built app. `make build` makes `dist/JustSessions.app`; set `DEMO_SOURCE_APP` to record another build.

## Setup

`demo-video setup` runs five steps in order. Each can also run on its own, as `demo-video setup <step>`.

| Step | What it does | What it changes |
| --- | --- | --- |
| `app` | Copies the built app as the demo app, with the bundle ID `dev.zichaoyang.justsessions.demo` and a launcher that gives it the isolated environment. Builds the input driver and the stage recorder. | `$DEMO_WORK`; the demo app's preferences in `~/Library/Preferences`. |
| `home` | Writes the demo home: sample projects, Claude Code conversations, a quiet shell prompt, and every CLI's settings. | `$DEMO_HOME`, `/Users/Shared/demo` by default. |
| `remote` | Adds the user `dev` to the VM with your test key and Claude Code, renames the VM to `devbox`, and adds a `devbox` alias to `~/.ssh/config`. | The VM; a marked block in `~/.ssh/config`. |
| `editing` | Makes the edit's Python environment and downloads the Kokoro narration model, about 340 MB, checked against its published checksums. | `$DEMO_WORK/.venv` and `$DEMO_WORK/models`. |
| `sessions` | Starts the background services, then runs Codex, OpenCode, and Pi once each in the demo home, names their sessions, and snapshots them. Run it again after a CLI update changes its session format. | `$DEMO_HOME`; `$DEMO_WORK/session-snapshot`. |

The background services are a canned model server on `127.0.0.1:18765` and a forward from `127.0.0.1:2222` to the VM's SSH port. `demo-video services start|stop|status` manages them. The demo app reaches the VM through that loopback forward because macOS Local Network privacy blocks a newly signed app from reaching the VM's address.

`$DEMO_WORK` defaults to the ignored `dist/demo-video/`. Keep its path short: the app's tmux socket lives in it, and macOS limits a socket path to 103 bytes. The scripts stop with a message when the path is too long.

## Record

```sh
Scripts/DemoVideo/demo-video record all
```

This records five takes into `$DEMO_WORK/takes`, each with the recorder's and driver's timestamped logs. The takes move the pointer and type, so turn on Do Not Disturb and leave the Mac alone until the last take reports. Each input step checks that the demo app is in front and aborts the take otherwise.

The takes build on each other. Sessions, search, and split view run on from one reset; new window replays those three unrecorded, shrinks the window, and records the drag; SSH starts from its own reset. `demo-video reset` puts the app and every sample session back to the start, so take A or E can be recorded alone with `demo-video reset` and then `demo-video record A-sessions`. Re-record B, C, or D with `record all`.

Each take is a JSON list of steps in `Scripts/DemoVideo/recording/takes/`. Clicks find their controls by accessibility label, so a layout change rarely breaks a take; D's drag ends at a fixed point set for its window frame. The edit's times and camera points follow the recorded takes, so check them with stills after re-recording.

## Edit

The cut is code. `editing/timeline/scenes.py` sets each scene's pieces of a take and their speeds, the camera, and when each narration line starts. `editing/voiceover/lines.json` holds the narration.

| Command | Output |
| --- | --- |
| `demo-video clicks` | `$DEMO_WORK/clicks.json`: where the pointer was at each click, for the click rings. Run it after recording. |
| `demo-video voiceover [voice] [speed] [line ids]` | `$DEMO_WORK/voiceover`: one WAV and its sentence timing per line. The defaults are `af_heart` at 1.1. |
| `demo-video stills <seconds>...` | `$DEMO_WORK/build/stills/<seconds>.png`, to check framing and captions without a render. |
| `demo-video render` | The master, `$DEMO_WORK/output/JustSessions-demo.mp4`. |
| `demo-video web <output.mp4>` | The homepage's smaller encode: H.264 CRF 24 with AAC 128 kbps and `+faststart`. |
| `demo-video poster <seconds> <output.jpg>` | A frame without its caption, for the homepage poster. |
| `demo-video window-still <seconds> <output.jpg>` | The app window alone at full resolution, for the social card. |

The render is deterministic: the same takes, click positions, and narration give a byte-identical master. Kokoro's speech is not. Two runs of the same line sound slightly different and can shift its timing by about 20 ms. To change some lines, pass their IDs, such as `demo-video voiceover af_heart 1.1 s2-search,s2-resume`, so the other lines keep their audio and timing.

Click positions are found by matching the pointer against a reference frame. After re-recording take A, update `REFERENCE` in `editing/analysis/find_click_positions.py` with a frame where the arrow sits on a light area, then run `demo-video clicks` again.

To publish, replace `website/media/justsessions-demo.mp4` and `justsessions-demo.jpg`, then update the chapter times in `website/index.html` and `website/media/README.md` from the scene starts in `$DEMO_WORK/build/timeline.json`, and the `VideoObject` duration in the homepage's structured data. [Website development](website.md) covers previews, chapter jumps, and the social card.

## Teardown

```sh
Scripts/DemoVideo/demo-video teardown
```

This quits the demo app and stops its tmux server, stops the background services, deletes the demo app's preferences and `$DEMO_HOME`, removes `dev` from the VM, restores the VM's hostname, and removes the `devbox` alias. It keeps `$DEMO_WORK` with the takes and renders; delete that folder yourself.
