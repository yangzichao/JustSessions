# Product website

The public website is at <https://yangzichao.github.io/JustSessions/>. Its source is plain HTML and CSS in `website/`; it has no JavaScript runtime, external fonts, analytics, or package dependencies. Downloads point to the latest GitHub Release, so an app release does not require a website update.

## Build and preview

From the repository root, with Python 3.10 or later:

```sh
python3 Scripts/Website/build_site.py
python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
```

Open <http://127.0.0.1:8765/JustSessions/>. The build checks local links and anchors across four pages, image references and dimensions, unique titles and descriptions, canonical and share metadata, structured app data, social-card dimensions, and sitemap completeness. The generated artifact is `dist/JustSessions/`, separate from the macOS app output. Only that website directory is uploaded to Pages.

The website reuses screenshots from `docs/images/` and existing `Branding/` assets at build time. Stylesheet links include a content hash so a new page loads the matching CSS after an update. Keep the sample-data captions and feature limitations accurate when replacing them. See [screenshot provenance](../images/README.md).

`feedback.html` is linked from the main navigation and footer, and included in the sitemap. Its three feedback actions open GitHub issue drafts with a title and report outline. Users review and submit on GitHub; the website has no feedback backend. Check both the homepage navigation and the feedback page at mobile widths after changing either.

## Pages and app colors

Keep the homepage brief. `guide.html` provides indexable setup instructions, the six-CLI compatibility table, SSH and tmux requirements, troubleshooting, and privacy details. The README and [getting-started guide](../guides/getting-started.md) link to it. Keep its behavior descriptions aligned with the repository guides and `ConversationProvider` capabilities when support changes.

`styles/app-theme.css` mirrors the app's default JustSessions light theme in `Sources/JustSessions/Models/Appearance/Themes/ThemeColors/JustSessionsThemeColors.swift`: warm content and sidebar surfaces, white raised controls, and Ink for primary actions. Shared page styles use these variables. The site keeps its light appearance; the Mac app can independently use its other themes and appearances. Recheck text contrast when adjusting secondary or muted colors.

## Search and sharing metadata

Each indexed page has a distinct title and description. Its Open Graph and Twitter title and description match those values; its canonical URL and `og:url` match the published page. `PUBLIC_PAGE_PATHS` in `Scripts/Website/validate_metadata.py` controls which pages are copied and included in the sitemap. Add a page there, supply its metadata, and link it from an existing page. The 404 page uses `noindex` and stays out of the sitemap.

The homepage's `SoftwareApplication` JSON-LD describes the real app, macOS requirement, free download, screenshot, source repository, and guide. Do not invent ratings or reviews to qualify for a search feature. Google requires a real rating or review for its software-app rich results; valid JSON-LD alone is not proof of eligibility. See Google's [software-app documentation](https://developers.google.com/search/docs/appearance/structured-data/software-app), [title guidance](https://developers.google.com/search/docs/appearance/title-link), and [description guidance](https://developers.google.com/search/docs/appearance/snippet).

Before publishing, build the site and check the homepage, guide, and feedback page at desktop and 390px widths. Confirm images load, links reach their intended sections, the comparison table scrolls inside its own region on narrow screens, and the browser reports no errors.

## Social preview

`website/social/preview.html` is the editable source for the checked-in `website/social/social-preview.png`. Serve the repository root locally, open the source in a browser with a 1200 × 630 viewport and device scale factor 1, then capture the `.social-card` element as a 1200 × 630 PNG. Only the PNG is published. The image uses the existing brand artwork; it does not contain a fabricated app screenshot.

## Deployment and discovery

The `Publish website` GitHub Actions workflow validates relevant pull requests and publishes relevant changes on `main`. It can also be run manually. Repository **Settings → Pages → Source** must be **GitHub Actions**. The deployment job uses the `github-pages` environment and narrowly scoped Pages and identity-token permissions.

The canonical URLs, Open Graph tags, JSON-LD, 404 home link, and `WEBSITE_URL` in `Scripts/Website/validate_metadata.py` share the public URL. Update all of them together if introducing a custom domain. The repository Website field and README link should match. Keep the repository description and topics current with supported tools and the SSH/tmux workflow.

The sitemap is published at `/JustSessions/sitemap.xml`. GitHub project sites cannot set the origin-level `/robots.txt`; the generated project-level file does not control crawler behavior. The page itself allows indexing, and the sitemap can be submitted directly in a verified Search Console property. Publication and valid metadata do not guarantee indexing or ranking.
