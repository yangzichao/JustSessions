"""Check the publishable website without third-party dependencies."""

import hashlib
import struct
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
from xml.etree import ElementTree

from script_assets import validate_script_imports
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
            if referenced_path.suffix in (".css", ".js", ".jpg", ".png", ".svg", ".mp4"):
                expected_version = hashlib.sha256(referenced_path.read_bytes()).hexdigest()[:12]
                assert parse_qs(parsed_reference.query).get("v") == [expected_version], f"Asset cache version mismatch: {reference}"
            if parsed_reference.fragment and referenced_path in documents:
                assert parsed_reference.fragment in documents[referenced_path].identifiers, f"Missing anchor: {reference}"

    validate_script_imports(website_directory)
    validate_metadata(documents, website_directory)
    homepage = documents[(website_directory / "index.html").resolve()]
    guide_page = documents[(website_directory / "guide.html").resolve()]
    assert "./help.html" not in homepage.references + guide_page.references, "Use Guide instead of a separate Help entry"
    assert {"ssh-hosts", "feedback"} <= guide_page.identifiers, "Guide needs SSH setup and feedback"
    assert "https://github.com/yangzichao/JustSessions/issues/new" in guide_page.references, "Guide needs issue reporting"
    assert "mailto:zichaoyangphys@gmail.com?subject=JustSessions%20feedback" in guide_page.references, "Guide needs email feedback"
    assert any(reference.startswith("./scripts/feedback/guide-feedback-form.js?v=") for reference in guide_page.references), "Guide needs the feedback form"
    app_verification_page = documents[(website_directory / "app-feedback-verification.html").resolve()]
    assert "noindex" in app_verification_page.metadata.get("robots", ""), "The app's feedback check page should not be indexed"
    assert any(reference.startswith("./scripts/feedback/app-verification.js?v=") for reference in app_verification_page.references), "The app's feedback check page needs its script"
    for document_name, destination in (("help.html", "./guide.html"), ("feedback.html", "./guide.html#feedback")):
        legacy_page = documents[(website_directory / document_name).resolve()]
        assert destination in legacy_page.references, f"{document_name} needs a Guide link"
        assert legacy_page.metadata.get("refresh") == f"0; url={destination}", f"{document_name} must redirect directly to Guide"
        assert legacy_page.canonical_url == WEBSITE_URL + "guide.html"
        assert "noindex" in legacy_page.metadata.get("robots", ""), f"{document_name} should not be indexed"
    image_header = (website_directory / "assets/social-preview.png").read_bytes()[:24]
    assert image_header[:8] == b"\x89PNG\r\n\x1a\n", "Social card must be a PNG"
    assert struct.unpack(">II", image_header[16:24]) == (1200, 630), "Social card must be 1200 x 630"
    sitemap = ElementTree.parse(website_directory / "sitemap.xml")
    namespace = {"sitemap": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    sitemap_urls = [element.text for element in sitemap.findall("sitemap:url/sitemap:loc", namespace)]
    assert sitemap_urls == [WEBSITE_URL + page_path for page_path in PUBLIC_PAGE_PATHS], "Sitemap differs from indexed pages"
    assert (website_directory / ".nojekyll").is_file()
    print(f"Website validation passed: {len(documents)} pages, local links, assets, stylesheet/script/image versions, anchors, metadata, JSON-LD, social card, sitemap.")
