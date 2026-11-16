# Product website

The public website is at <https://yangzichao.github.io/JustSessions/>. Its source is static HTML and CSS in `website/`, with small native JavaScript modules for the demo video's play button and chapters, anonymous traffic counts, and the Guide's feedback form. It has no framework, external fonts, or package dependencies; the only third-party script is Cloudflare Turnstile, which the feedback form loads from Cloudflare when a visitor first moves into it. Every Download button, including the homepage and Guide navigation bars, points directly to the latest GitHub Release DMG. It starts a download rather than scrolling to a section or opening a release page, so an app release does not require a website update.

## Build and preview

From the repository root, with Python 3.10 or later and Node.js 22.7 or later for script tests:

```sh
make website-check
python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
```

Open <http://127.0.0.1:8765/JustSessions/>. The build checks local links and anchors across six pages, image references and dimensions, unique titles and descriptions, canonical and share metadata, structured app data, social-card dimensions, and sitemap completeness. The generated artifact is `dist/JustSessions/`, separate from the macOS app output. Only that website directory is uploaded to Pages.

It also checks visible CLI names, commands, and preview/branch/SSH/deletion cells in the online guide, README, and storage guide against `ConversationProvider.swift` and `TranscriptLoader.swift`. This runs without compiling Swift, including on the release workflow's Linux runner. The source reader recognizes their explicit case switches and fails if the representation changes; update it rather than skipping validation. `make website-check` runs both the website tests and build, and is included in local `make verify`. Conflicting claims block verification and release publication.

The homepage's capability summary uses `data-capability` and `data-support="all|some|none"` on its reading, deletion, SSH, and branching claims. The same check compares these markers with the app's capabilities, so a stale homepage summary also blocks publication. Keep each marker on the sentence or phrase describing that capability.

The website reuses screenshots from `docs/images/` and existing `Branding/` assets at build time. Local stylesheet, script, module import, and image links include a content hash so a new page loads matching assets after an update. The build versions script imports before their parent modules and validates all versions. Keep screenshot provenance and sample-data details in [the image documentation](../images/README.md).

The homepage is built around a 53-second narrated demo, `website/media/justsessions-demo.mp4`, with its poster `justsessions-demo.jpg`. It shows sessions grouped by project, Resume, Codex, OpenCode, and Pi, search, tabs and split view, a tab dragged into a new window, and an SSH task that keeps running after its tab closes. Captions are burned in, so it reads without sound. See [media provenance](../../website/media/README.md) for the recording, sample data, narration, music, and chapter times, and [Demo video](demo-video.md) for the scripts that record and edit it. The video and poster receive content-hashed URLs.

The page never plays the demo by itself, and `preload="metadata"` fetches only the file's header until someone plays it. With JavaScript, the poster shows one **Watch the demo** button. That button and each chapter start playback with sound, and then the native controls take over. Six chapter buttons are the tabs of an app window drawn around the video: Sessions, Agents, Search, Tabs & split, New window, and SSH. Each jumps to its point and plays, also after the demo has ended. Each tab's bar fills as the video plays, and the playing chapter has `aria-current`, which draws it as the selected tab. The tabs copy the app's tab shape in `WorkspaceTabShape.swift`, as in Chrome: the selected tab has rounded top corners and feet that curve into the video below, and the others show an inset fill under the pointer and a short line between them. `styles/demo-chapter-tabs.css` has the tab strip. Their `data-start` and `data-end` seconds must match the video; update them together with the media README. Without JavaScript the video keeps its native controls, and the play button and chapters stay hidden. `scripts/demo-video/demo-video-player.js` has this behavior, and `demo-video.js` connects it to the page.

The video is centered under the hero. Its width follows the window height, so the title, the tab strip, and the video fit in the first screen of a 1440 × 820 window. The tab strip always stays one row. When the window around the video is narrower than 880px (a container query, since its width also follows the browser's height), tabs show only their icons and the playing tab widens to show its name. The video has its own dark background, so loading never flashes white behind it.

`make website-check` also runs dependency-free Node tests for the demo player: the initial play button, the switch to native controls, chapter jumps (also after the end), and chapter progress. Python tests reject stale video, poster, script, and imported-module cache versions. Both website validation workflows set up Node 22 explicitly.

Chapter jumps need byte-range responses. GitHub Pages sends them. `python3 -m http.server` does not, so in that preview a jump restarts the video from the beginning. Check chapter jumps on the published site, or with a local server that answers Range requests.

`guide.html#feedback` offers a feedback form (see [Feedback](#feedback)), **Report an issue**, and **Email feedback**. The form stays hidden without JavaScript, leaving the two links. Keep these destinations aligned with `Models/App/AppLinks.swift`. The old `help.html` URL redirects directly to Guide, and `feedback.html` redirects to its Feedback section. Both redirects use `noindex` and stay out of the sitemap. Check both old URLs after changing navigation or the Guide.

## Shared top bar and footer

The homepage, Guide, and comparison page share one top bar and one footer. Guide is the only help destination; its top-bar link has a question-mark icon, and Source has the existing GitHub Octicon from `Branding/ThirdParty/Octicons/mark-github-16.svg`. Both links keep accessible names when phone layouts show only their icons. Their markup is in `website/partials/site-header.html` (including the skip link) and `website/partials/site-footer.html`, and all of their styles are in `styles/site-header.css` and `styles/site-footer.css`. Each page has a `<!-- partial: site-header -->` and a `<!-- partial: site-footer -->` line where they go; `Scripts/Website/shared_partials.py` inserts the partials during the build and adds `aria-current="page"` to links for the current page. The build fails if one of these pages defines its own `<header>` or `<footer>`, omits a placeholder, or does not load the matching stylesheet, and `test_shared_partials.py` checks that the built bars and footers are identical apart from the current-page marker. Change them only in the partials and their stylesheets; page stylesheets must not restyle `.site-header` or `.site-footer`. The 404 page and the old Help and Feedback redirects have neither.

## Pages and app colors

Keep the homepage to a compact hero, the narrated demo video with its chapters, the supported agents, and four concise FAQ answers. The hero says “Nothing extra. Just sessions.” followed by “Multiple agents, all your sessions in one place. Your familiar command line, with native tabs.” This explains the product's distinction: familiar CLI interaction with lightweight native session management. Keep this text prominent and compact so the video and its chapters stay in the first screen; use the same positioning in search and social descriptions. The top bar's “Download for Mac” label says the app is macOS-only; phones show “Download” to fit. Do not add an eyebrow, extra summary, or another title above the video. The top bar's Download button is the homepage's only download action; do not add another above the video or at the bottom of the page. Do not add eyebrow labels, download footnotes, or feature cards that repeat the video. Detailed setup and feature descriptions belong in the Guide. `guide.html` provides indexable setup instructions, the six-CLI compatibility table, SSH and tmux requirements, troubleshooting, and privacy details. The README and [getting-started guide](../guides/getting-started.md) link to it. Keep its behavior descriptions aligned with the repository guides and `ConversationProvider` capabilities when support changes.

When a user-facing feature changes, update its guide and README entry in the same change. Mention its benefit on the homepage with a short sentence or guide link, then update page summaries and GitHub About only where needed. Source builds can be ahead of the latest signed installer: label unreleased controls in the guides and check release notes before presenting them as available in the download. Keep screenshot captions accurate until the actual interface captures are refreshed.

The homepage borrows the app icon's comic look, described in [Branding](../../Branding/README.md): ink outlines, hard offset shadows, and halftone dots. The demo window sits on orange and purple panels stacked like the mark's speech bubbles, with the mark's three dots as its window controls; the agents are outlined stickers and the FAQ answers are outlined panels. The tokens are `--comic-outline`, `--comic-shadow`, and `--comic-halftone` in `styles/foundation.css`, and the shared **Download** button uses an orange hard shadow on every page. Keep the hero itself plain: the title's orange marker stroke is its only decoration.

`styles/app-theme.css` mirrors the app's default JustSessions light theme in `Sources/JustSessions/Models/Appearance/Themes/ThemeColors/JustSessionsThemeColors.swift`: warm content and sidebar surfaces, white raised controls, and Ink for primary actions. Shared page styles use these variables. The site keeps its light appearance; the Mac app can independently use its other themes and appearances. Recheck text contrast when adjusting secondary or muted colors.

The homepage's agent list pairs each visible name with a decorative inline SVG matching the app's sidebar symbol in `Views/Branding/Providers/`. Its color variables in `styles/app-theme.css` mirror the light colors in `Models/Appearance/Themes/Hues/ConversationProvider+TintHexColor.swift`. Keep both aligned when the app's provider identity changes. The list sits under the video with a small “Works with your CLIs” heading: one centered row on wide screens and two columns on phones. `styles/providers.css` handles both layouts.

The footer links to `compare.html`, with one-sentence differences from Agent Sessions, opcode, cmux, and Superset, followed by a matrix of the two closest history tools. An adjacent-tools section covers Paseo, Happy, Claude Squad, Warp, Ghostty, and iTerm2, grouped by remote clients, parallel agents, and terminals. Explain each tool's purpose and how JustSessions' existing-history workflow differs. Link primary documentation next to the comparisons, record the check date, and describe undocumented capabilities without claiming they are absent. The comparison page has no traffic-count script. Its focused stylesheet lives in `styles/comparison/`; the build versions nested CSS files too.

## Search and sharing metadata

Each indexed page has a distinct title and description. Its Open Graph and Twitter title and description match those values; its canonical URL and `og:url` match the published page. `PUBLIC_PAGE_PATHS` in `Scripts/Website/validate_metadata.py` controls which pages are copied and included in the sitemap. Add a page there, supply its metadata, and link it from an existing page. The 404 page uses `noindex` and stays out of the sitemap.

The homepage title identifies the Claude Code and Codex CLI workspace for macOS. Its summary explains session management, the existing CLI workflow, native tabs, split view, SSH, and bundled tmux without adding visible copy. Keep the approved hero and feature bullets concise; supported agent names and features are already in the static HTML and remain readable without JavaScript.

The homepage's `SoftwareApplication` JSON-LD describes the real app, macOS and CLI requirements, free download, the demo poster as its screenshot, the demo as a `VideoObject`, source repository, and guide. Its description must match the search summary. The build versions absolute social-image and structured-data image URLs with the same content hashes as local assets; validation rejects stale share images, and screenshots or demo video URLs that do not appear on the page. Open Graph and Twitter use matching image alt text. Do not invent ratings or reviews to qualify for a search feature. Google requires a real rating or review for its software-app rich results; valid JSON-LD alone is not proof of eligibility. See Google's [software-app documentation](https://developers.google.com/search/docs/appearance/structured-data/software-app), [title guidance](https://developers.google.com/search/docs/appearance/title-link), and [description guidance](https://developers.google.com/search/docs/appearance/snippet).

Before publishing, build the site and check the homepage, Guide, and comparison page at desktop, 390px, and 320px widths, and confirm the old Help and Feedback URLs reach Guide. Confirm images load, the demo plays with sound from its button and from each chapter, links reach their intended sections, the comparison table scrolls inside its own region on narrow screens, and the browser reports no errors.

## Social preview

`website/social/preview.html` is the editable source for the checked-in `website/social/social-preview.png`. Serve the repository root locally, open the source in a browser with a 1200 × 630 viewport and device scale factor 1, then capture the `.social-card` element as a 1200 × 630 PNG. Only the PNG is published. The card pairs “Nothing extra. Just sessions.” with the existing brand artwork and the split-view moment from the homepage demo in `docs/images/demo-split-view.jpg`: Claude Code and Codex side by side, with local projects and the `devbox` SSH host in the sidebar. The app window extends slightly beyond the card's right edge; its sidebar and CLI remain visible. Keep the headline aligned with the homepage and replace the capture when the app UI changes. Update the matching Open Graph and Twitter image alt text on every page that shares the card: the homepage, Guide, comparison, and release notes. Headless Chrome can also capture it from the repository root, though it may keep running after writing the file: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 --screenshot=website/social/social-preview.png "file://$PWD/website/social/preview.html"`. Recording and sample-data details remain in [screenshot provenance](../images/README.md).

Slack and other sharing clients read the published Open Graph / Twitter metadata to select this image; they do not capture the homepage video. The build gives the shared PNG a content-hashed URL, including in structured app data. After deployment, check both page metadata and the PNG with a Slackbot-style request. This proves the resources are accessible, rather than verifying the final Slack message layout. Slack can cache link metadata; use its [URL debugger](https://api.slack.com/tools/unfurl-debugger) or a private Slack message to inspect the actual preview.

If the browser exports JPEG, convert it before saving the published PNG: `sips -s format png /path/to/capture.jpg --out website/social/social-preview.png`. Confirm the output is a 1200 × 630 PNG with `file website/social/social-preview.png`; changing the extension alone does not change the format.

## Deployment and discovery

### Traffic counts

The homepage and Guide each send one background request per page load to the independent Cloudflare Worker in `Cloudflare/WebsiteTraffic/`, on the same account as the update-feed Worker. The client in `website/scripts/traffic/` runs only on the published origin and known page paths; local previews, redirect/error pages, browsers declaring WebDriver automation, Global Privacy Control, and Do Not Track produce no count. Playing the demo video does not trigger requests. It sends no cookies, credentials, full page URL, full referrer, or visitor identifier, and a blocked or failed request does not affect the website.

The `justsessions-website-traffic` D1 database stores aggregate counts keyed by UTC day, page (`home` or `guide`), a fixed referral category, country, and coarse device type. The Worker never stores IP addresses, raw user agents, or individual events; persisted logs and traces are disabled. A daily scheduled task removes totals older than 180 days. Cloudflare and GitHub still serve requests under their own policies. The Guide includes a concise disclosure.

```sh
make website-traffic         # Daily page views, sources, countries, and devices for the last 30 days
make website-traffic-test    # Worker boundary tests, also included in make website-check
make website-traffic-deploy  # Apply D1 migrations and deploy the independent Worker
./Cloudflare/WebsiteTraffic/show-website-traffic.sh 90
```

These are page views, not unique visitors: reloads count again, and blocked scripts or privacy opt-outs are absent. Known bot user agents are excluded, but the public collection endpoint is not proof of human traffic. Source categories depend on the referrer the browser exposes; missing referrers appear as direct. Read aggregate data through the authenticated D1 command or Cloudflare dashboard; the Worker exposes no public statistics endpoint.

### Feedback

The Guide's form posts to the `justsessions-feedback` Worker in `Cloudflare/Feedback/`, on the same account as the other Workers. The app has no form of its own: **Settings → Send feedback** and **Help → Send Feedback** open `guide.html?appVersion=…&macOSVersion=…#feedback` in the browser. Its endpoint, the Turnstile site key and action, and the length limits are in `website/scripts/feedback/feedback-contract.js`, and `app-versions.js` reads and checks the versions; the Worker imports both, and its tests check that `AppLinks.swift`, `FeedbackLinks.swift`, and the D1 schema agree.

Each submission carries a [Cloudflare Turnstile](https://developers.cloudflare.com/turnstile/) token. The Worker accepts only JSON of the exact shape the form sends, up to 64 KiB, then applies a rate limit of 3 requests per minute per IP address and Cloudflare location, then checks the token with Siteverify: it must be valid, unused, solved on `yangzichao.github.io` for the `feedback` action, and carry the submission's source (`website` or `app`) as its cData. Only then does it store the message, the optional contact, the source, and the app's versions. It never stores IP addresses, user agents, or tokens; persisted logs are disabled. A daily scheduled task deletes feedback older than 365 days. Requests from other sites, or without an `Origin`, are refused.

The Guide loads Turnstile only after the visitor first focuses the form, renders it with `cData: "website"`, and uses each token once. When the address carries both versions and each passes the Worker's check, the form shows them, renders Turnstile with `cData: "app"`, and sends the feedback as the app's with those versions. The app does not embed Turnstile: in a `WKWebView` its challenge never finishes and fails with error 300010.

```sh
make feedback          # The newest 20 entries, newest first
make feedback-test     # Worker and contract tests, also included in make website-check
make feedback-deploy   # Apply D1 migrations and deploy the Worker
./Cloudflare/Feedback/show-feedback.sh 100
wrangler tail --config Cloudflare/Feedback/wrangler.jsonc   # Watch live errors; message text is never logged
```

The Turnstile widget **JustSessions feedback** is registered for `yangzichao.github.io` only, in Managed mode. Its secret is the Worker secret `TURNSTILE_SECRET_KEY` (`wrangler secret put TURNSTILE_SECRET_KEY` in `Cloudflare/Feedback/`); it is never committed. Without it, the Worker answers `unavailable`. A token from a local preview fails the hostname check, so test end to end on the published site, or locally with Cloudflare's [test keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/). If the website moves to a custom domain, add it to the widget, `turnstileHostname`, and `publishedWebsiteOrigin` together.

### Publishing

The independent `Publish JustSessions website` workflow tests, builds, and deploys the website when relevant files change on `main`. This includes website sources, screenshots, branding, website scripts, and the app capability sources and documentation checked by the website build. It does not build or publish the app. The release notes page lists only versions whose GitHub release is published, so notes merged before tagging stay hidden until the app release workflow redeploys the site; local builds show every entry. Run `make verify` and, for workflow changes, `actionlint` locally before pushing. See [build and release](build-and-release.md).

To redeploy without changing files or creating a version tag, choose **Actions → Publish JustSessions website → Run workflow → main**, or run:

```sh
gh workflow run publish-website.yml --ref main
```

Automatic and manual runs build current `main`; selecting another branch skips the build and deployment. The workflow records the checked-out source revision in its build summary. Runs are serialized across both build and deployment, and an active deployment finishes before the next starts. App releases retain website validation but do not deploy Pages, so an app release cannot replace a newer website with its tagged copy. Pull requests and other branch pushes do not deploy.

Repository **Settings → Pages → Source** must be **GitHub Actions**. The `github-pages` environment's selected deployment branches must allow `main`. The deployment job uses narrowly scoped Pages and identity-token permissions.

The canonical URLs, Open Graph tags, JSON-LD, 404 home link, and `WEBSITE_URL` in `Scripts/Website/validate_metadata.py` share the public URL. Update all of them together if introducing a custom domain. The repository Website field and README link should match. Keep the repository description and topics current with supported tools and the SSH/tmux workflow.

The sitemap is published at `/JustSessions/sitemap.xml`. GitHub project sites cannot set the origin-level `/robots.txt`; the generated project-level file does not control crawler behavior. The page itself allows indexing, and the sitemap can be submitted directly in a verified Search Console property. Publication and valid metadata do not guarantee indexing or ranking.
