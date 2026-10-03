# Working on JustSessions

## Checks before you push

The Test workflow in CI runs only `swift test`. The localization check and the packaged-app launch check run locally:

```sh
make verify
```

Run it before opening a pull request or pushing to `main`, and say in the pull request that it passed. Run it again on the commit you tag for a release: the release workflow does not rerun the tests or the localization check.

`make verify` runs `make test` and `make localization-check`, builds `dist/JustSessions.app`, and opens it for 8 seconds to check it keeps running. Reopening the last quit's tabs is off for that launch, so it starts no CLIs.

For a faster loop while working, `make check` compiles the development build and `make test` runs the tests against the bundled tmux runtime. After changing UI copy, run `make localization` and add the missing translations; see [Interface localization](docs/development/localization.md).

## More

- [Build and release](docs/development/build-and-release.md): Make commands, the bundled tmux runtime, CI, and release signing.
- [Source layout](docs/development/source-layout.md): where each feature lives.
