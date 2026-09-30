"""Assemble the static Pages artifact from the website and existing brand assets."""

import shutil
from pathlib import Path

from validate_site import WEBSITE_URL, validate_site

REPOSITORY_DIRECTORY = Path(__file__).resolve().parents[2]
WEBSITE_SOURCE_DIRECTORY = REPOSITORY_DIRECTORY / "website"
WEBSITE_OUTPUT_DIRECTORY = REPOSITORY_DIRECTORY / "dist/JustSessions"


def build_site():
    WEBSITE_OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    asset_directory = WEBSITE_OUTPUT_DIRECTORY / "assets"
    asset_directory.mkdir(exist_ok=True)
    for document_name in ("index.html", "404.html"):
        shutil.copy2(WEBSITE_SOURCE_DIRECTORY / document_name, WEBSITE_OUTPUT_DIRECTORY / document_name)
    shutil.copytree(WEBSITE_SOURCE_DIRECTORY / "styles", WEBSITE_OUTPUT_DIRECTORY / "styles", dirs_exist_ok=True)
    for image_name in ("session-overview.jpg", "remote-desktop-sessions.jpg", "tmux-keep-running.jpg"):
        shutil.copy2(REPOSITORY_DIRECTORY / "docs/images" / image_name, asset_directory / image_name)
    for asset_path in ("Branding/SVG/mark.svg", "Branding/PNG/app-icon-256.png", "website/social/social-preview.png"):
        shutil.copy2(REPOSITORY_DIRECTORY / asset_path, asset_directory / Path(asset_path).name)
    (WEBSITE_OUTPUT_DIRECTORY / ".nojekyll").touch()
    (WEBSITE_OUTPUT_DIRECTORY / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {WEBSITE_URL}sitemap.xml\n")
    (WEBSITE_OUTPUT_DIRECTORY / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"  <url><loc>{WEBSITE_URL}</loc></url>\n"
        "</urlset>\n"
    )
    validate_site(WEBSITE_OUTPUT_DIRECTORY)
    print(f"Built website: {WEBSITE_OUTPUT_DIRECTORY}")


if __name__ == "__main__":
    build_site()
