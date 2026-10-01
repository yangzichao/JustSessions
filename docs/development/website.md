# Product website

The public website is at <https://yangzichao.github.io/JustSessions/>. Its source is plain HTML and CSS in `website/`; it has no JavaScript runtime, external fonts, analytics, or package dependencies. Downloads point to the latest GitHub Release, so an app release does not require a website update.

## Build and preview

From the repository root, with Python 3.10 or later:

```sh
python3 Scripts/Website/build_site.py
python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
```

Open <http://127.0.0.1:8765/JustSessions/>. The build checks local links, anchors, image references and dimensions, required metadata, structured data, social-card dimensions, and the sitemap. The generated artifact is `dist/JustSessions/`, separate from the macOS app output. Only that website directory is uploaded to Pages.

The website reuses screenshots from `docs/images/` and existing `Branding/` assets at build time. Stylesheet links include a content hash so a new page loads the matching CSS after an update. Keep the sample-data captions and feature limitations accurate when replacing them. See [screenshot provenance](../images/README.md).

`feedback.html` is linked from the main navigation and footer, and included in the sitemap. Its three feedback actions open GitHub issue drafts with a title and report outline. Users review and submit on GitHub; the website has no feedback backend. Check both the homepage navigation and the feedback page at mobile widths after changing either.

## Social preview

`website/social/preview.html` is the editable source for the checked-in `website/social/social-preview.png`. Serve the repository root locally, open the source in a browser with a 1200 × 630 viewport and device scale factor 1, then capture the `.social-card` element as a 1200 × 630 PNG. Only the PNG is published. The image uses the existing brand artwork; it does not contain a fabricated app screenshot.

## Deployment and discovery

The `Publish website` GitHub Actions workflow validates relevant pull requests and publishes relevant changes on `main`. It can also be run manually. Repository **Settings → Pages → Source** must be **GitHub Actions**. The deployment job uses the `github-pages` environment and narrowly scoped Pages and identity-token permissions.

The canonical URL, Open Graph tags, JSON-LD, 404 home link, and build script's `WEBSITE_URL` share the public URL. Update all of them together if introducing a custom domain. The repository Website field and README link should match.

The sitemap is published at `/JustSessions/sitemap.xml`. GitHub project sites cannot set the origin-level `/robots.txt`; the generated project-level file does not control crawler behavior. The page itself allows indexing, and the sitemap can be submitted directly in a verified Search Console property. Publication and valid metadata do not guarantee indexing or ranking.
