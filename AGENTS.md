# Working on JustSessions

## Checks before you push

GitHub Actions runs only when a version tag is pushed. Pull requests, branch pushes, and merges to `main` do not run CI. Developers and coding agents must complete the checks locally:

```sh
make verify
```

Run it on the final commit before opening or updating a pull request, merging, or pushing to `main`. Rerun it after code changes, conflict resolution, or rebasing. Do not merge or push failing checks, or substitute a GitHub Actions run for local verification.

Use the PR template to attach the tested commit SHA, verification date, macOS and Swift versions, exact commands and results, and a concise log summary. Update that evidence whenever the PR head changes; identify any failures or checks that were not run explicitly. Include relevant manual checks for behavior changes. For direct pushes to `main`, report the same evidence in the delivery summary.

`make verify` runs the website tests and build, `make test`, and `make localization-check`, builds `dist/JustSessions.app`, and opens it for 8 seconds to check it keeps running. Reopening the last quit's tabs is off for that launch, so it starts no CLIs. After editing workflows, also run `actionlint` locally.

Run `make verify` again on the exact commit you tag for a release. The single release workflow validates the website, reruns the Swift tests and localization checks, then signs and publishes the app and deploys the website from the same tag. Website changes on `main` become public at the next release.

For a faster loop while working, `make check` compiles the development build and `make test` runs the tests against the bundled tmux runtime. After changing UI copy, run `make localization` and add the missing translations; see [Interface localization](docs/development/localization.md).

## More

- [Build and release](docs/development/build-and-release.md): Make commands, the bundled tmux runtime, CI, and release signing.
- [Source layout](docs/development/source-layout.md): where each feature lives.
