# Building and releasing JustSessions

[Back to JustSessions](../../README.md) · [Source layout](source-layout.md)

## Build from source

Requires macOS 14+ and a Swift 6 toolchain (Xcode Command Line Tools). Run these commands from the repository root.

```sh
make check  # Compile the Swift development build
make test   # Run tests against the bundled tmux runtime
make verify # Check the website, tests, localization, and packaged app launch
make        # Package dist/JustSessions.app, including tmux
make dev    # Build the app, quit its running copy, and open it
```

`make help` lists the commands. `make run` is an alias for `make dev`. `make dmg` packages `dist/JustSessions.dmg`, and `make website` builds and validates the product site. Set `APP_BUNDLE_PATH` or `INSTALLER_PATH` to change the output paths, for example `make build APP_BUNDLE_PATH="dist/JustSessions Preview.app"`. The targets use the existing build scripts and respect their version and signing environment variables.

`build-app.sh` builds a pinned tmux runtime from checksum-verified upstream archives, statically links libevent, ncurses, and utf8proc, and packages the binary, terminal database, and license notices under `Contents/Resources/Tmux`. The first package build downloads sources; subsequent builds reuse the verified runtime when its build fingerprint matches. End users need no separate tmux install. Direct `swift run` development builds still use an installed tmux 3.3+.

```sh
./Scripts/Tmux/build-runtime.sh
python3 Scripts/Tmux/verify-runtime.py .build/Tmux/arm64/runtime
JUSTSESSIONS_TEST_TMUX_RUNTIME="$PWD/.build/Tmux/arm64/runtime" swift test
```

The verifier relocates the runtime to a path with spaces, restricts `PATH` to system tools, checks system-only dynamic linkage and license notices, checks that tmux targets the `macos_deployment_target` from `Scripts/Tmux/versions.sh` (macOS 14.0) with no weak imports, and detaches and reattaches a real terminal client without replacing the running process. Both local `make test` and the release workflow build this runtime before testing, so tmux integration tests run against the shipped binary. Local builds reuse it when the build fingerprint matches; the release workflow builds it from source without an Actions cache. `build-app.sh` signs the nested tmux executable before signing the app; the existing notarization and Sparkle archive include it. The runtime build compiles against the active SDK but must run on macOS 14: calls to newer APIs fail the build, and a weak import means a dependency's `configure` found a newer function, such as `pipe2()` in the macOS 27 SDK, which is missing on older macOS and crashes tmux. Disable such functions in `Scripts/Tmux/build-helpers.sh`. Update `Scripts/Tmux/versions.sh` and its archive checksums together when upgrading dependencies, and retest client/server compatibility with existing sessions.

## Performance measurements

Run these opt-in suites separately, with a release build, so their visible test windows do not compete for the main thread:

```sh
JUSTSESSIONS_PERF=1 swift test -c release --filter SidebarInteractionMeasurements
JUSTSESSIONS_PERF=1 swift test -c release --filter TerminalVisibilityMeasurements
```

The sidebar suite records interaction time and main-thread heartbeat gaps at 300 and 2,000 sessions. The terminal suite replays continuous ANSI output through five or ten SwiftTerm views, comparing the original opacity-only behavior with inactive-output coalescing. It reports process CPU as a percentage of one core, taking the median of three runs; it starts no CLI sessions. These are controlled workloads, not battery-life measurements.

Discovery metadata is cached under the app's macOS Caches directory in `SessionSummaries`. The snapshots are versioned and disposable; each entry is checked against the source file's size, modification date, and inode before use. A missing, incompatible, or corrupt cache falls back to reading source files.

## Releases

GitHub Actions runs only for pushed version tags (`vX.Y.Z`). Pull requests, branch pushes, and merges to `main` run no workflows. Run `make verify` locally on the final commit before opening or updating a pull request, merging, pushing to `main`, or tagging a release. It runs the website tests and build, the [update feed Worker](update-checks.md) tests, Swift tests against bundled tmux, and localization checks, then builds the app and opens it with `Scripts/Release/check-app-launches.sh`. The check hides the resource bundles in `.build/release`, because SwiftPM's `Bundle.module` falls back to that absolute path on the build machine but not on users' Macs.

Use the PR template to record the tested commit SHA, verification date, macOS and Swift versions, commands, results, and a concise log summary. Refresh the evidence after each PR update, including rebases and conflict resolution. Workflow changes also require local `actionlint`. Required checks must pass before merging or pushing; report the same evidence in the delivery summary for direct pushes to `main`. Repository merge rules must not require the retired `Test` or website CI checks.

The single `Publish JustSessions release` workflow first validates the tag and website on Linux, then runs Swift tests and localization checks on macOS before Developer ID signing, notarization, and app publication. Only after app publication succeeds does it deploy the website artifact from the same tag. There are no scheduled or manual workflow triggers; use GitHub's rerun facility to retry a failed tag run. The tag sets the app version. Choose a new, unused semantic version for each release:

Before tagging user-facing changes, update the README, affected user guides, and concise homepage copy or guide links in the same change. Run `python3 Scripts/Website/build_site.py` to check capability claims against the app and validate the Pages artifact. After the signed installer is published, update any source-build availability notes that became part of the release. See [website maintenance](website.md).

```sh
# Replace vX.Y.Z with the next release version.
git tag vX.Y.Z
git push origin vX.Y.Z
```

Tag the exact commit that passed local `make verify`. The release workflow reruns tests and localization checks and runs the same launch check on the signed app before notarizing it. Each release includes the notarized `JustSessions.dmg`, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` used for updates. Apps fetch that appcast through the update feed Worker, which counts checks per day; see [Counting update checks](update-checks.md). CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.
