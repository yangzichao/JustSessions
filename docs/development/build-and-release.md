# Building and releasing JustSessions

[Back to JustSessions](../../README.md) · [Source layout](source-layout.md)

## Build from source

Requires macOS 14+ and Swift 6.2 or later (Xcode 26 or its Command Line Tools), which libghostty-spm needs. Run these commands from the repository root.

```sh
make check  # Compile the Swift development build
make test   # Run tests against the bundled tmux runtime
make verify # Check the website, tests, localization, and packaged app launch
make        # Package dist/JustSessions.app, including tmux
make dev    # Build the app, quit its running copy, and open it
```

`make help` lists the commands. `make run` is an alias for `make dev`. `make dmg` packages `dist/JustSessions.dmg`, and `make website` builds and validates the product site. Set `APP_BUNDLE_PATH` or `INSTALLER_PATH` to change the output paths, for example `make build APP_BUNDLE_PATH="dist/JustSessions Preview.app"`. The targets use the existing build scripts and respect their version and signing environment variables.

A local build's version is the commit it was built from, as `Scripts/Version/describe-development-version.sh` prints it from `git describe`: `1.1.0-3-gf45492c` is three commits after v1.1.0, and `-dirty` marks uncommitted changes to tracked files. Settings → General, feedback, and crash reports show it with build number 0. Local builds don't check for updates on their own; **Check for updates** still offers the latest release, and installing it replaces the build. Only the release workflow sets `APP_VERSION`, from the tag, together with `APP_BUILD_NUMBER`.

`build-app.sh` builds a pinned tmux runtime from checksum-verified upstream archives, statically links libevent, ncurses, and utf8proc, and packages the binary, terminal database, and license notices under `Contents/Resources/Tmux`. The first package build downloads sources; subsequent builds reuse the verified runtime when its build fingerprint matches. End users need no separate tmux install. Direct `swift run` development builds still use an installed tmux 3.3+.

```sh
./Scripts/Tmux/build-runtime.sh
python3 Scripts/Tmux/verify-runtime.py .build/Tmux/arm64/runtime
JUSTSESSIONS_TEST_TMUX_RUNTIME="$PWD/.build/Tmux/arm64/runtime" swift test
```

The verifier relocates the runtime to a path with spaces, restricts `PATH` to system tools, checks system-only dynamic linkage and license notices, checks that tmux targets the `macos_deployment_target` from `Scripts/Tmux/versions.sh` (macOS 14.0) with no weak imports, and detaches and reattaches a real terminal client without replacing the running process. Both local `make test` and the release workflow build this runtime before testing, so tmux integration tests run against the shipped binary. Local builds reuse it when the build fingerprint matches; the release workflow builds it from source without an Actions cache. `build-app.sh` signs the nested tmux executable before signing the app; the existing notarization and Sparkle archive include it. The runtime build compiles against the active SDK but must run on macOS 14: calls to newer APIs fail the build, and a weak import means a dependency's `configure` found a newer function, such as `pipe2()` in the macOS 27 SDK, which is missing on older macOS and crashes tmux. Disable such functions in `Scripts/Tmux/build-helpers.sh`. Update `Scripts/Tmux/versions.sh` and its archive checksums together when upgrading dependencies, and retest client/server compatibility with existing sessions.

## SwiftTerm fork

The terminal comes from [yangzichao/SwiftTerm](https://github.com/yangzichao/SwiftTerm), a fork of [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). Its `minimum-contrast-1.15` branch is upstream `v1.15.0` plus two commits:

- `minimumContrastRatio`: text whose color falls below the ratio against its cell's background, after dimming, is darkened or lightened just enough to reach it, as in VS Code's terminal. Box drawing and block elements keep their colors. The app sets the ratio to 4.5 in `TerminalAppearanceStyling`. SwiftTerm draws selected text in the one selection text color without that minimum, so the app first makes that color readable on the selection (`TerminalColorScheme.readableSelectionForeground`). Upstream merged it in [#747](https://github.com/migueldeicaza/SwiftTerm/pull/747), after `v1.99.0`.
- Cells as wide as the font's glyph for the character W, not the glyph it names W. Fonts whose glyphs are unnamed or named by CID, such as BIZ UDGothic, BIZ UDMincho, and PCMyungjo, name no glyph W, which made every cell as wide as a Chinese character. `SwiftTermCellWidth` mirrors this for the font picker and Ghostty's cell size. Upstream review: [#749](https://github.com/migueldeicaza/SwiftTerm/pull/749).

Fork tags are named `v<upstream version>-justsessions.<n>`, and `Package.swift` pins one exactly. To move to a newer SwiftTerm, rebase the commits upstream doesn't have onto the upstream tag, run `swift test` in the fork, push a new tag, and update `Package.swift` and `Package.resolved`. Drop the fork once an upstream release has both changes.

## libghostty

The Ghostty terminal engine comes from [libghostty-spm](https://github.com/Lakr233/libghostty-spm), through a fork that `Package.swift` pins exactly. It provides `libghostty.a` prebuilt from a pinned upstream Ghostty commit with its own patches, as a binary target SwiftPM downloads with the package (about 77 MB), and the `GhosttyTerminal` AppKit view around it. Nothing here builds Ghostty or needs Zig.

`Package.swift` pins [yangzichao/libghostty-spm](https://github.com/yangzichao/libghostty-spm), a fork. Its `justsessions-search-counts` branch is upstream `2.2.2026100901` plus one commit. That commit passes Ghostty's search count and selected match on to `TerminalSurfaceSearchDelegate`, which the find bar needs to show "2 of 14" in a Ghostty tab. The upstream wrapper dropped these reports. Upstream review: [Lakr233/libghostty-spm#82](https://github.com/Lakr233/libghostty-spm/pull/82). The commit changes only Swift code. The fork's manifest downloads the same `libghostty.a` archive, with the same URL and checksum, so the library and its licenses are upstream's. Fork tags are named `<upstream version>-justsessions.<n>`, without a `v`, as upstream's tags are. To move to a newer release:

1. Rebase the commit onto the upstream tag.
2. Run `swift test` in the fork.
3. Push a new tag.
4. Update `Package.swift` and `Package.resolved`.

Drop the fork once an upstream release forwards the search reports.

`Scripts/build-app.sh` copies `GhosttyKit_GhosttyTerminal.bundle`, Ghostty's shell integration and terminfo, into the app. Ghostty's package finds it through SwiftPM's generated resource accessor and stops the app when that finds nothing. Only Swift Build, the default from Swift 6.4, makes an accessor that looks in the app's `Contents/Resources`; the native build system, the default on the release runner's older Swift, makes one that looks only beside the `.app` and in the building machine's own build folder, which stopped v1.2.0 on every other Mac as soon as Ghostty was chosen. So `build-app.sh` builds with `--build-system swiftbuild` and takes its paths from `--show-bin-path`, and fails when the build has no bundle. The launch check opens the app with `-checksGhosttyResourcesAtLaunch YES`, which makes the Ghostty controller a terminal makes first and quits if the bundle or its resources can't be found, with the build folder's bundles hidden, so the app must find its own copy. The library adds about 9 MB to the app's executable, measured on `2.2.2026100901` in an arm64 release build (13.9 MB without it, 22.9 MB with it), and the bundle about 124 KB.

The library statically links Ghostty's dependencies, including FreeType, Oniguruma, libpng, zlib, GNU libintl, and its built-in fonts. Their license texts, versions, and the obligations still open are in `Branding/ThirdParty/Ghostty/`, which the app ships as `Contents/Resources/Ghostty-Licenses`. To move to a newer release, update the pin and `Package.resolved`, then recheck that folder against the new archive's members, as its README describes.

The release workflow tests on a GitHub virtual machine, where Ghostty drew its background in the configured color but its text and cell colors in others. The rendering tests that check those exact colors skip there (`TestMachine.isVirtual`), so `make verify` on a Mac is what checks them before a release.

## Gherkin features

Behavior that reads best as a story is written as Gherkin in `Tests/JustSessionsTests/Gherkin/Features/`, one folder per feature, and run by [CucumberSwift](https://github.com/cucumberswift/CucumberSwift) as part of `make test`. Each feature's steps live beside it under `Tests/JustSessionsTests/Gherkin/` and register in `CucumberStepImplementation.swift`, the one step implementation SwiftPM's single test bundle allows. A step matches by its text in every feature, so steps that read the same in several features, such as what a tab or the sidebar shows, are written once in `Gherkin/Shared/` and reach each tool's world through `CurrentSessionTabWorld`. A step's text cannot hold `|`: CucumberSwift's lexer reads it as the start of a table cell and drops the rest of the line.

CucumberSwift makes an XCTest case for each step when the run starts, so `swift test list` does not show them, `swift test --filter` cannot pick a scenario, and `swift test --parallel` runs none of them while still passing. Run them with plain `swift test`, as `make test` does. `CUCUMBER_VERBOSE=1 make test` prints each scenario's result; `CUCUMBER_TAGS=<tag> swift test` runs only the scenarios with that tag.

## End-to-end tests in a tmux sandbox

Tests that need the app's own launch, tmux, and CLI activity sync run in `ThisMacTmuxSandbox`: a private tmux server with its own home folder and a `bin` folder of stand-in CLIs, so the app's own server and your sessions are never touched. `Activity/UnseenTurns/EndToEnd/` runs the unseen-turn dot and the Waiting for you filter this way. Its `StandInActivityCLI` scripts report what they do as Claude Code and Codex do, in the live registry and the rollout file, and as Pi and OpenCode do, in the report file their extension writes, only when the app started them with it. A test drives them by typing in their tab's terminal. A tab starts its CLI with only that `bin` folder on `PATH`, so a stand-in sets its own. These tests pass without running where tmux is missing or too old, so run them through `make test`, which provides the bundled tmux.

## Live CLI checks

`LiveCLIEvidence` runs the Claude Code and Codex CLIs installed on this Mac in real tabs, directly and in a sandboxed tmux server, and saves a PNG and the screen text of each terminal. It is opt-in, since it starts the real CLIs; each run gives them a home folder and settings folders of their own, so they show their first-run screen and never read your sessions or settings:

```sh
JUSTSESSIONS_LIVE_EVIDENCE=1 JUSTSESSIONS_LIVE_EVIDENCE_DIRECTORY="$(mktemp -d)" \
CLAUDE_CONFIG_DIR="$(mktemp -d)" CODEX_HOME="$(mktemp -d)" \
JUSTSESSIONS_TEST_TMUX_RUNTIME="$(./Scripts/Tmux/build-runtime.sh)" swift test --filter LiveCLIEvidence
```

Add `JUSTSESSIONS_LIVE_SSH_HOST=<host>` to also open a tab on an SSH host, such as the [test VM](ssh-testing.md): a login shell, and Claude Code if the host has it, with a settings folder of its own that the test removes afterwards.

## Performance measurements

Run these opt-in suites separately, with a release build, so their visible test windows do not compete for the main thread:

```sh
JUSTSESSIONS_PERF=1 swift test -c release --filter SidebarInteractionMeasurements
JUSTSESSIONS_PERF=1 swift test -c release --filter TerminalVisibilityMeasurements
JUSTSESSIONS_PERF=1 JUSTSESSIONS_PERF_SAMPLE_DIR=/tmp/engine-profiles swift test -c release --filter 'TerminalEngineMeasurements/(tuiRepaint|bulkStream|hiddenTabsRepaint)'
for round in 1 2 3; do
  for memory_case in ghostty swiftTerm swiftTerm10k swiftTermMetal; do
    JUSTSESSIONS_PERF=1 JUSTSESSIONS_PERF_MEMORY_CASE=$memory_case swift test -c release --filter TerminalEngineMeasurements/memory
  done
done
```

The sidebar suite records interaction time and main-thread heartbeat gaps at 300 and 2,000 sessions. The terminal suite replays continuous ANSI output through five or ten SwiftTerm views, comparing the original opacity-only behavior with inactive-output coalescing. It reports process CPU as a percentage of one core, taking the median of three runs; it starts no CLI sessions. These are controlled workloads, not battery-life measurements.

The engine suite runs the same output through a Ghostty tab, a SwiftTerm tab, and a SwiftTerm tab drawing with Metal (see [item 6](performance.md#6-terminal-drawing)), from a script on each tab's own pseudo-terminal: a TUI-style repaint, a 20 MB log stream, and the repaint with hidden tabs. It reports process and main-thread CPU, the longest main-thread gap, and frames drawn, as the median of three runs that alternate the engines. With `JUSTSESSIONS_PERF_SAMPLE_DIR` set, it also saves a `sample` profile of each engine's repaint there. Its memory test measures one case per process, since a second run in the same process reads too low, so the loop above runs each case three times. See [Performance](performance.md#terminal-engines-ghostty-and-swiftterm) for the method and results.

Discovery metadata is cached under the app's macOS Caches directory in `SessionSummaries`. The snapshots are versioned and disposable; each entry is checked against the source file's size, modification date, and inode before use. A missing, incompatible, or corrupt cache falls back to reading source files.

## Releases

### Curated release notes

`Sources/JustSessions/Resources/ReleaseNotes/releases.json` is the shared editorial history for Settings → General → Release notes,
the [website release notes](https://yangzichao.github.io/JustSessions/release-notes.html), GitHub release bodies, and Sparkle's update window.
Before tagging, add the version, release date (the publication day in America/Los_Angeles), a short title, and user-facing changes under
`new`, `improved`, or `fixed`. Keep newest versions first and include English and Simplified Chinese copy. Follow the required
[release-note writing standard and editorial review](release-notes.md): aim for 1–3 concrete bullets, with at most 5, and verify each claim
against the changes since the previous release. The initial history covers the published
1.0 releases; v1.0.7 repackaged the same source as v1.0.6.

Preview a version's GitHub Markdown and Sparkle HTML with:

```sh
python3 Scripts/ReleaseNotes/prepare_release_notes.py v1.0.9 --output-directory dist/release-notes
make website
```

The release workflow fails before signing if the tag has no curated entry or the copy fails the automated editorial checks. It publishes the rendered Markdown as the GitHub release body
and gives Sparkle a matching `JustSessions.html` beside `JustSessions.zip`, which `generate_appcast --embed-release-notes` embeds in the feed.
The native history is bundled and works offline; its website link opens newer notes. Adding entries triggers the independent website build, but the website lists only versions whose GitHub release is published;
after publishing, the release workflow redeploys it. Local website builds show every entry.
Historical GitHub release bodies are not changed by a source commit and need a separate publication when backfilling notes.

### Signed publication

App release Actions run for pushed version tags (`vX.Y.Z`). Website changes on `main` also run an independent website workflow, which can be triggered manually from `main`. Pull requests and other branch pushes run no workflows. Run `make verify` locally on the final commit before opening or updating a pull request, merging, pushing to `main`, or tagging a release; website Actions do not replace it. It runs the website tests and build, the traffic and [feedback](website.md#feedback) Worker tests, the [update feed Worker](update-checks.md) tests, Swift tests against bundled tmux, and localization checks, then builds the app and opens it with `Scripts/Release/check-app-launches.sh`. The check hides the resource bundles in `.build/release`, because SwiftPM's `Bundle.module` falls back to that absolute path on the build machine but not on users' Macs.

Use the PR template to record the tested commit SHA, verification date, macOS and Swift versions, commands, results, and a concise log summary. Refresh the evidence after each PR update, including rebases and conflict resolution. Workflow changes also require local `actionlint`. Required checks must pass before merging or pushing; report the same evidence in the delivery summary for direct pushes to `main`. Repository merge rules must not require the retired `Test` or website CI checks.

The `Publish JustSessions release` workflow first validates the tag and website on Linux, then runs Swift tests and localization checks on macOS before Developer ID signing, notarization, and app publication. It does not deploy Pages itself; after publishing, it starts the website workflow so the release notes page lists the new version. App releases have no scheduled or manual triggers; use GitHub's rerun facility to retry a failed tag run. To update or redeploy the website independently, use the [website workflow](website.md#deployment-and-discovery). The tag sets the app version. Choose a new, unused semantic version for each release:

Before tagging user-facing changes, update the README, affected user guides, and concise homepage copy or guide links in the same change. Run `python3 Scripts/Website/build_site.py` to check capability claims against the app and validate the Pages artifact. After the signed installer is published, update any source-build availability notes that became part of the release. See [website maintenance](website.md).

```sh
# Replace vX.Y.Z with the next release version.
# Complete the editorial review, commit the notes, and check that exact commit.
make release-check RELEASE_TAG=vX.Y.Z
git tag vX.Y.Z
git push origin vX.Y.Z
```

Tag the exact commit that passed local `make verify`. The release workflow reruns tests and localization checks and runs the same launch check on the signed app before notarizing it. Each release includes the notarized `JustSessions.dmg`, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` used for updates. Apps fetch that appcast through the update feed Worker, which counts checks per day; see [Counting update checks](update-checks.md). CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.
