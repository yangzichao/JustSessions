## Changes

Describe the problem and resulting behavior.

## Local verification

PRs and non-main branch pushes do not run GitHub Actions. Website deployment checks on `main` do not replace local app verification. Complete this section for the current PR head before merging, and refresh it after every update.

- Tested commit SHA:
- Verification date:
- macOS version:
- Swift version:

| Command | Result | Log summary |
| --- | --- | --- |
| `make verify` | PASS / FAIL / NOT RUN | Website tests/build, update feed Worker tests, Swift tests, localization, packaged-app build and launch |
| `actionlint` (workflow changes) | PASS / FAIL / NOT APPLICABLE | |

Include test counts or a concise output excerpt; attach longer logs when useful. State any failures or checks not run explicitly. All required checks must pass before merging.

Manual checks for changed behavior:
