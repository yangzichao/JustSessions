# Building and releasing JustSessions

[Back to JustSessions](../../README.md) · [Source layout](source-layout.md)

## Build from source

Requires macOS 14+ and a Swift 6 toolchain (Xcode Command Line Tools). Run these commands from the repository root.

```sh
swift build
swift test
./Scripts/build-app.sh
open "dist/JustSessions.app"
```

## Releases

Pushes to `main` and pull requests run `swift test`. Pushing a version tag makes GitHub Actions build, Developer ID sign, notarize, and publish the app; the tag sets the app version. Choose a new, unused semantic version for each release:

Before tagging user-facing changes, update the README, affected user guides, and concise homepage copy or guide links in the same change. Run `python3 Scripts/Website/build_site.py` to check capability claims against the app and validate the Pages artifact. After the signed installer is published, update any source-build availability notes that became part of the release. See [website maintenance](website.md).

```sh
# Replace vX.Y.Z with the next release version.
git tag vX.Y.Z
git push origin vX.Y.Z
```

Each release includes the notarized `JustSessions.dmg`, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` used for updates. CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.
