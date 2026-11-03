# JustSessions documentation

[Project home](../README.md) · [Website](https://yangzichao.github.io/JustSessions/) · [Online quick guide](https://yangzichao.github.io/JustSessions/guide.html)

## Use the app

| Guide | Covers |
| --- | --- |
| [Getting started](guides/getting-started.md) | Install, discover existing sessions, resume, and troubleshoot missing tools. |
| [Session management](guides/session-management.md) | Search, reading windows and controls, pins, branching, project tabs, shortcuts, notifications, SSH, cleanup, and themes. |
| [Session storage and privacy](guides/session-storage.md) | CLI file locations, capability limits, SSH caching, native deletion, and tmux behavior. |

## Develop and publish

| Guide | Covers |
| --- | --- |
| [Build and release](development/build-and-release.md) | Swift builds, tests, signed installers, notarization, and Sparkle updates. |
| [SSH development testing](development/ssh-testing.md) | A local Ubuntu test host for Mac contributors, macOS coverage, and live SSH checks. |
| [Source layout](development/source-layout.md) | Feature folders and responsibilities. |
| [Feature requirements](requirements/README.md) | Behavior, UI, and performance the project chose on purpose, with origins and tests; check it to avoid regressions. |
| [Extensions (proposal)](development/extensions.md) | The planned extension panel, its first four extensions, OpenUI, SSH support, and the requirements they change. |
| [Performance](development/performance.md) | Profiling baseline, known hotspots, the status of each optimization, and how to profile. |
| [Counting update checks](development/update-checks.md) | The Cloudflare Worker that counts daily update checks, what it stores, and how to read the numbers. |
| [UI style](development/ui-style.md) | Theme colors, type scale, corner radii, button and sheet rules, and the contract tests that enforce them. |
| [Interface localization](development/localization.md) | String Catalog, language discovery, adding translations, and automated checks. |
| [Website development](development/website.md) | Static Pages builds, app colors, metadata, sitemap, previews, and publishing. |
| [Demo video](development/demo-video.md) | Recording and editing the homepage's narrated demo from an isolated copy of the app. |
| [Branding](../Branding/README.md) | Icon sources, brand colors, and asset generation. |
| [Screenshot provenance](images/README.md) | Real interface captures, sample data, and their limits. |

## Help

Use the [Guide](https://yangzichao.github.io/JustSessions/guide.html) for features, SSH setup, and feedback, including installing tmux on the remote host. In the app, open **Settings → Help** or **Help → JustSessions Help**. For feedback, choose **Send feedback** at the bottom of **Settings → General** to open the Guide's feedback form in your browser, or **Report an issue** to open one on GitHub. Both start with your app and macOS versions filled in.
