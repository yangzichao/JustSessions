# Contributing to JustSessions

Bug reports, documentation, translations, accessibility improvements, and focused code changes are welcome. Please follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Report a problem or suggest a feature

Search [existing issues](https://github.com/yangzichao/JustSessions/issues) first, then use the [issue forms](https://github.com/yangzichao/JustSessions/issues/new/choose). Include your JustSessions and macOS versions, the CLI and its version when relevant, whether the session is local or over SSH, and steps to reproduce the problem.

Remove credentials, private conversation text, and identifying paths or hostnames from logs and screenshots. Use small, synthetic session examples when possible. Report vulnerabilities privately using the [security policy](SECURITY.md); report accessibility barriers using the [accessibility statement](ACCESSIBILITY.md).

For help using the app, see the [user guide](https://yangzichao.github.io/JustSessions/guide.html) or email [zichaoyangphys@gmail.com](mailto:zichaoyangphys@gmail.com). For substantial features or architectural changes, open an issue to discuss the approach before implementing it.

## Build and develop

Use macOS 14 or later on Apple Silicon and a Swift 6 toolchain from Xcode or the Xcode Command Line Tools.

```sh
git clone https://github.com/yangzichao/JustSessions.git
cd JustSessions
git switch -c your-change
make check  # Compile the development build
make test   # Test against the bundled tmux runtime
make dev    # Package and open dist/JustSessions.app
```

The first tmux build downloads checksum-verified upstream sources. See [build and release](docs/development/build-and-release.md) for dependencies, Gherkin scenarios, and packaging, and [source layout](docs/development/source-layout.md) for the feature folders. [Website development](docs/development/website.md) covers the product site.

Use descriptive names and small, focused files grouped by feature. Keep each pull request focused on one problem, preserve unrelated work, and include regression tests when they help verify a behavior change. Do not commit real session history, credentials, or generated build artifacts.

For UI copy or translations, follow [interface localization](docs/development/localization.md). Edit `Localization/Localizable.xcstrings`, run `make localization`, and commit the catalog with its generated resources. Do not edit generated localization files directly.

## Verify and submit

Commit your final changes, then run:

```sh
make verify
```

This checks the website tests and build, update feed Worker tests, Swift tests against bundled tmux, and localization, then builds the packaged app and checks that it keeps running for eight seconds. The launch check disables reopening tabs so it starts no CLIs. After changing GitHub Actions workflows, also run `actionlint` locally.

Open a pull request against `main` and complete the [PR template](.github/pull_request_template.md): describe the problem and resulting behavior, provide the tested commit SHA, verification date, macOS and Swift versions, exact commands and results, a concise log summary, and relevant manual checks.

Run `make verify` again after any code change, conflict resolution, or rebase, and update the verification evidence for the new PR head. All required checks must pass before merging or pushing to `main`. Pull requests and other branch pushes do not run CI; website deployment checks on `main` do not replace local app verification. Maintainers publish app releases by pushing version tags after verifying the exact tagged commit.
