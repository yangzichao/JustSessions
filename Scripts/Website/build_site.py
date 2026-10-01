"""Assemble the static Pages artifact from the website and existing brand assets."""

import hashlib
import shutil
from pathlib import Path

from validate_metadata import PUBLIC_PAGE_PATHS, WEBSITE_URL
from validate_site import validate_site

REPOSITORY_DIRECTORY = Path(__file__).resolve().parents[2]
WEBSITE_SOURCE_DIRECTORY = REPOSITORY_DIRECTORY / "website"
WEBSITE_OUTPUT_DIRECTORY = REPOSITORY_DIRECTORY / "dist/JustSessions"


def build_site():
    WEBSITE_OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    asset_directory = WEBSITE_OUTPUT_DIRECTORY / "assets"
    asset_directory.mkdir(exist_ok=True)
    document_names = tuple(page_path or "index.html" for page_path in PUBLIC_PAGE_PATHS) + ("404.html",)
    for document_name in document_names:
        shutil.copy2(WEBSITE_SOURCE_DIRECTORY / document_name, WEBSITE_OUTPUT_DIRECTORY / document_name)
    stylesheet_directory = WEBSITE_OUTPUT_DIRECTORY / "styles"
    if stylesheet_directory.exists():
        shutil.rmtree(stylesheet_directory)
    shutil.copytree(WEBSITE_SOURCE_DIRECTORY / "styles", stylesheet_directory)
    for image_name in ("session-overview.jpg", "remote-desktop-sessions.jpg", "tmux-keep-running.jpg"):
        shutil.copy2(REPOSITORY_DIRECTORY / "docs/images" / image_name, asset_directory / image_name)
    for asset_path in ("Branding/SVG/mark.svg", "Branding/PNG/app-icon-256.png", "website/social/social-preview.png"):
        shutil.copy2(REPOSITORY_DIRECTORY / asset_path, asset_directory / Path(asset_path).name)
    for document_path in WEBSITE_OUTPUT_DIRECTORY.glob("*.html"):
        document_content = document_path.read_text()
        for stylesheet_path in stylesheet_directory.glob("*.css"):
            stylesheet_version = hashlib.sha256(stylesheet_path.read_bytes()).hexdigest()[:12]
            stylesheet_reference = f"./styles/{stylesheet_path.name}"
            document_content = document_content.replace(
                f'href="{stylesheet_reference}"',
                f'href="{stylesheet_reference}?v={stylesheet_version}"',
            )
        document_path.write_text(document_content)
    (WEBSITE_OUTPUT_DIRECTORY / ".nojekyll").touch()
    (WEBSITE_OUTPUT_DIRECTORY / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {WEBSITE_URL}sitemap.xml\n")
    sitemap_entries = "".join(f"  <url><loc>{WEBSITE_URL}{page_path}</loc></url>\n" for page_path in PUBLIC_PAGE_PATHS)
    (WEBSITE_OUTPUT_DIRECTORY / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{sitemap_entries}</urlset>\n"
    )
    validate_site(WEBSITE_OUTPUT_DIRECTORY)
    print(f"Built website: {WEBSITE_OUTPUT_DIRECTORY}")


if __name__ == "__main__":
    build_site()
