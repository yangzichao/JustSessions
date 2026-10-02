"""Check the publishable website without third-party dependencies."""

import hashlib
import struct
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
from xml.etree import ElementTree

from validate_metadata import PUBLIC_PAGE_PATHS, WEBSITE_URL, validate_metadata
from website_document import WebsiteDocument


def validate_site(website_directory: Path):
    documents = {}
    for document_path in website_directory.rglob("*.html"):
        document = WebsiteDocument()
        document.feed(document_path.read_text())
        assert document.heading_count == 1, f"Expected one h1 in {document_path.name}"
        documents[document_path.resolve()] = document

    for document_path, document in documents.items():
        for reference in document.references:
            parsed_reference = urlparse(reference)
            if parsed_reference.scheme or parsed_reference.netloc:
                continue
            referenced_path = (document_path.parent / unquote(parsed_reference.path)).resolve()
            if not parsed_reference.path:
                referenced_path = document_path
            elif referenced_path.is_dir():
                referenced_path /= "index.html"
            assert referenced_path.is_relative_to(website_directory.resolve()), f"Asset leaves published directory: {reference}"
            assert referenced_path.is_file(), f"Missing local target: {reference}"
            if referenced_path.suffix == ".css":
                expected_version = hashlib.sha256(referenced_path.read_bytes()).hexdigest()[:12]
                assert parse_qs(parsed_reference.query).get("v") == [expected_version], f"Stylesheet cache version mismatch: {reference}"
            if parsed_reference.fragment and referenced_path in documents:
                assert parsed_reference.fragment in documents[referenced_path].identifiers, f"Missing anchor: {reference}"

    validate_metadata(documents, website_directory)
    homepage = documents[(website_directory / "index.html").resolve()]
    help_page = documents[(website_directory / "help.html").resolve()]
    assert "./help.html" in homepage.references, "Homepage needs a Help entry"
    assert "remote-hosts" in help_page.identifiers, "Help needs remote host setup"
    assert "./guide.html#ssh-hosts" in help_page.references, "Help needs detailed SSH instructions"
    legacy_feedback = documents[(website_directory / "feedback.html").resolve()]
    assert "./help.html" in legacy_feedback.references, "Old Feedback URL needs a Help link"
    assert legacy_feedback.canonical_url == WEBSITE_URL + "help.html"
    assert "noindex" in legacy_feedback.metadata.get("robots", ""), "Old Feedback URL should not be indexed"
    image_header = (website_directory / "assets/social-preview.png").read_bytes()[:24]
    assert image_header[:8] == b"\x89PNG\r\n\x1a\n", "Social card must be a PNG"
    assert struct.unpack(">II", image_header[16:24]) == (1200, 630), "Social card must be 1200 x 630"
    sitemap = ElementTree.parse(website_directory / "sitemap.xml")
    namespace = {"sitemap": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    sitemap_urls = [element.text for element in sitemap.findall("sitemap:url/sitemap:loc", namespace)]
    assert sitemap_urls == [WEBSITE_URL + page_path for page_path in PUBLIC_PAGE_PATHS], "Sitemap differs from indexed pages"
    assert (website_directory / ".nojekyll").is_file()
    print(f"Website validation passed: {len(documents)} pages, local links, assets, stylesheet versions, anchors, metadata, JSON-LD, social card, sitemap.")
