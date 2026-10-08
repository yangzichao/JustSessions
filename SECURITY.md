# Security policy

## Supported versions

Security fixes are provided in the latest published JustSessions release. Older releases do not receive separate security backports. Update through **Settings → General** or download the [latest release](https://github.com/yangzichao/JustSessions/releases/latest). Reports affecting the current `main` branch are also welcome.

## Report a vulnerability privately

Use GitHub's [Report a vulnerability](https://github.com/yangzichao/JustSessions/security/advisories/new) form. Reports are private to the reporter and the maintainers handling them.

If you cannot use GitHub private reporting, email [zichaoyangphys@gmail.com](mailto:zichaoyangphys@gmail.com) with the subject **JustSessions security report**. Send an initial description without credentials or sensitive attachments; we can arrange how to share further details.

Please include:

- The affected JustSessions version or commit and your macOS version.
- The affected feature, CLI version, and whether it involves this Mac or an SSH host.
- Steps to reproduce, preferably with a minimal synthetic example.
- The expected and observed behavior, potential impact, and any suggested fix.

Keep exploit details out of public issues, pull requests, and comments until we have coordinated disclosure. Do not include API keys, SSH keys, access tokens, or private conversation history in a report.

## Scope and response

Reports may cover the native app, its bundled runtime and update handling, session reading and deletion, SSH integration, and the website or Workers maintained in this repository. If a problem belongs to a CLI provider or an upstream dependency, report it to that project's maintainers as well and explain how it affects JustSessions.

We will review the report, ask for any needed reproduction details, and coordinate a fix and disclosure with you. Response and fix timing depend on severity and maintainer availability. We will discuss attribution before publishing an advisory.

For ordinary bugs and usage questions, use the [issue forms](https://github.com/yangzichao/JustSessions/issues/new/choose) or [user guide](https://yangzichao.github.io/JustSessions/guide.html). See [session storage and privacy](docs/guides/session-storage.md) for the app's data handling.
