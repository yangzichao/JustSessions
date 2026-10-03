# Building and releasing JustSessions

[Back to JustSessions](../../README.md) · [Source layout](source-layout.md)

## Build from source

Requires macOS 14+ and a Swift 6 toolchain (Xcode Command Line Tools). Run these commands from the repository root.

```sh
make check  # Compile the Swift development build
make test   # Run tests against the bundled tmux runtime
make verify # Run the tests and localization checks, then check the packaged app opens
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

The verifier relocates the runtime to a path with spaces, restricts `PATH` to system tools, checks system-only dynamic linkage and license notices, checks that tmux targets the `macos_deployment_target` from `Scripts/Tmux/versions.sh` (macOS 14.0) with no weak imports, and detaches and reattaches a real terminal client without replacing the running process. The test workflow builds this runtime before testing, so tmux integration tests run against the shipped binary; it caches the runtime between runs and rebuilds it when `Scripts/Tmux` or the SDK changes. The release workflow always builds it from source. `build-app.sh` signs the nested tmux executable before signing the app; the existing notarization and Sparkle archive include it. The runtime build compiles against the active SDK but must run on macOS 14: calls to newer APIs fail the build, and a weak import means a dependency's `configure` found a newer function, such as `pipe2()` in the macOS 27 SDK, which is missing on older macOS and crashes tmux. Disable such functions in `Scripts/Tmux/build-helpers.sh`. Update `Scripts/Tmux/versions.sh` and its archive checksums together when upgrading dependencies, and retest client/server compatibility with existing sessions.

## Releases

Pushes to `main` and pull requests run only `swift test` in CI. Run `make verify` locally before tagging a release: it also runs `make localization-check`, then builds the app and opens it with `Scripts/Release/check-app-launches.sh`. The check hides the resource bundles in `.build/release`, because SwiftPM's `Bundle.module` falls back to that absolute path on the build machine but not on users' Macs. Pushing a version tag makes GitHub Actions build, Developer ID sign, notarize, and publish the app; the tag sets the app version. Choose a new, unused semantic version for each release:

Before tagging user-facing changes, update the README, affected user guides, and concise homepage copy or guide links in the same change. Run `python3 Scripts/Website/build_site.py` to check capability claims against the app and validate the Pages artifact. After the signed installer is published, update any source-build availability notes that became part of the release. See [website maintenance](website.md).

```sh
# Replace vX.Y.Z with the next release version.
git tag vX.Y.Z
git push origin vX.Y.Z
```

Tag a commit that passed the Test workflow and `make verify`: the release workflow does not rerun the tests or localization checks. It runs the same launch check on the signed app before notarizing it. Each release includes the notarized `JustSessions.dmg`, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` used for updates. CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.
