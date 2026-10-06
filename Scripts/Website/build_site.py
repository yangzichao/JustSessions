"""Assemble the static Pages artifact from the website and existing brand assets."""

import hashlib
import shutil
from pathlib import Path

from script_assets import version_script_imports
from shared_partials import insert_shared_partials, validate_partial_placeholders
from validate_metadata import PUBLIC_PAGE_PATHS, WEBSITE_URL
from validate_product_content import validate_product_content
from validate_site import validate_site

REPOSITORY_DIRECTORY = Path(__file__).resolve().parents[2]
WEBSITE_SOURCE_DIRECTORY = REPOSITORY_DIRECTORY / "website"
WEBSITE_OUTPUT_DIRECTORY = REPOSITORY_DIRECTORY / "dist/JustSessions"


def build_site():
    validate_product_content(REPOSITORY_DIRECTORY)
    validate_partial_placeholders(WEBSITE_SOURCE_DIRECTORY)
    WEBSITE_OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    asset_directory = WEBSITE_OUTPUT_DIRECTORY / "assets"
    asset_directory.mkdir(exist_ok=True)
    document_names = tuple(page_path or "index.html" for page_path in PUBLIC_PAGE_PATHS) + ("404.html", "help.html", "feedback.html")
    for document_name in document_names:
        shutil.copy2(WEBSITE_SOURCE_DIRECTORY / document_name, WEBSITE_OUTPUT_DIRECTORY / document_name)
        insert_shared_partials(WEBSITE_OUTPUT_DIRECTORY / document_name, WEBSITE_SOURCE_DIRECTORY / "partials")
    stylesheet_directory = WEBSITE_OUTPUT_DIRECTORY / "styles"
    if stylesheet_directory.exists():
        shutil.rmtree(stylesheet_directory)
    shutil.copytree(WEBSITE_SOURCE_DIRECTORY / "styles", stylesheet_directory)
    script_directory = WEBSITE_OUTPUT_DIRECTORY / "scripts"
    if script_directory.exists():
        shutil.rmtree(script_directory)
    shutil.copytree(WEBSITE_SOURCE_DIRECTORY / "scripts", script_directory)
    version_script_imports(script_directory)
    for image_name in ("session-overview.jpg", "native-terminal.jpg", "split-terminal.jpg", "remote-desktop-sessions.jpg", "tmux-keep-running.jpg", "tmux-close-choice.jpg"):
        shutil.copy2(REPOSITORY_DIRECTORY / "docs/images" / image_name, asset_directory / image_name)
    for asset_path in ("Branding/SVG/mark.svg", "Branding/ThirdParty/Octicons/mark-github-16.svg", "Branding/PNG/app-icon-256.png", "website/social/social-preview.png", "website/annotations/ssh-host-highlight.svg", "website/annotations/project-agents-highlight.svg"):
        shutil.copy2(REPOSITORY_DIRECTORY / asset_path, asset_directory / Path(asset_path).name)
    for media_path in (WEBSITE_SOURCE_DIRECTORY / "media").iterdir():
        if media_path.suffix in (".mp4", ".jpg"):
            shutil.copy2(media_path, asset_directory / media_path.name)
    for document_path in WEBSITE_OUTPUT_DIRECTORY.glob("*.html"):
        document_content = document_path.read_text()
        for resource_path in (*stylesheet_directory.rglob("*.css"), *script_directory.rglob("*.js"), *asset_directory.iterdir()):
            if not resource_path.is_file():
                continue
            resource_version = hashlib.sha256(resource_path.read_bytes()).hexdigest()[:12]
            resource_reference = f"./{resource_path.relative_to(WEBSITE_OUTPUT_DIRECTORY).as_posix()}"
            absolute_reference = WEBSITE_URL + resource_path.relative_to(WEBSITE_OUTPUT_DIRECTORY).as_posix()
            for reference in (resource_reference, absolute_reference):
                document_content = document_content.replace(
                    f'"{reference}"',
                    f'"{reference}?v={resource_version}"',
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
