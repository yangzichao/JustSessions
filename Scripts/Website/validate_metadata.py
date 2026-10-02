"""Keep published titles, summaries, canonical URLs, and app data consistent."""

import json
from pathlib import Path

WEBSITE_URL = "https://yangzichao.github.io/JustSessions/"
PUBLIC_PAGE_PATHS = ("", "guide.html", "help.html")


def validate_metadata(documents, website_directory: Path):
    titles = set()
    descriptions = set()
    for page_path in PUBLIC_PAGE_PATHS:
        document_name = page_path or "index.html"
        document = documents[(website_directory / document_name).resolve()]
        expected_url = WEBSITE_URL + page_path
        assert document.language == "en", f"Missing page language: {document_name}"
        assert document.title.strip(), f"Missing title: {document_name}"
        assert document.title not in titles, f"Duplicate page title: {document_name}"
        titles.add(document.title)
        assert document.canonical_url == expected_url, f"Canonical URL differs: {document_name}"
        for metadata_name in (
            "description", "viewport", "og:title", "og:description", "og:image",
            "twitter:card", "twitter:title", "twitter:description", "twitter:image", "twitter:image:alt",
        ):
            assert document.metadata.get(metadata_name), f"Missing {metadata_name}: {document_name}"
        description = document.metadata["description"]
        assert description not in descriptions, f"Duplicate page description: {document_name}"
        descriptions.add(description)
        assert document.metadata["og:title"] == document.title, f"Share title differs: {document_name}"
        assert document.metadata["twitter:title"] == document.title, f"Twitter title differs: {document_name}"
        assert document.metadata["og:description"] == description, f"Share summary differs: {document_name}"
        assert document.metadata["twitter:description"] == description, f"Twitter summary differs: {document_name}"
        assert document.metadata["og:url"] == expected_url
        assert document.metadata["og:image"] == WEBSITE_URL + "assets/social-preview.png"
        assert document.metadata["twitter:image"] == document.metadata["og:image"]
        assert "noindex" not in document.metadata.get("robots", "")

    homepage = documents[(website_directory / "index.html").resolve()]
    structured_data = json.loads(homepage.structured_data)
    assert structured_data["url"] == WEBSITE_URL
    assert structured_data["@id"] == WEBSITE_URL + "#app"
    assert structured_data["@type"] == "SoftwareApplication"
    assert structured_data["name"] == "JustSessions"
    assert structured_data["applicationCategory"] == "DeveloperApplication"
    assert structured_data["operatingSystem"] == "macOS 14 or later (Apple Silicon)"
    assert structured_data["offers"]["price"] == "0"
    assert structured_data["downloadUrl"] in homepage.references
    assert structured_data["softwareHelp"]["url"] == WEBSITE_URL + "help.html"
    assert "./guide.html" in homepage.references, "Homepage needs a guide entry"

    not_found_page = documents[(website_directory / "404.html").resolve()]
    assert "noindex" in not_found_page.metadata.get("robots", ""), "404 page should not be indexed"
