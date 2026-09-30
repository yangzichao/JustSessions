"""Check the publishable website without third-party dependencies."""

import json
import struct
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse
from xml.etree import ElementTree

WEBSITE_URL = "https://yangzichao.github.io/JustSessions/"


class WebsiteDocument(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.references = []
        self.identifiers = set()
        self.metadata = {}
        self.heading_count = 0
        self.canonical_url = None
        self.structured_data = ""
        self.reading_structured_data = False

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        for reference in (attributes.get("href"), attributes.get("src")):
            if reference is not None:
                assert reference.strip(), "Empty link or asset reference"
                self.references.append(reference)
        if "id" in attributes:
            identifier = attributes["id"]
            assert identifier not in self.identifiers, f"Duplicate ID: {identifier}"
            self.identifiers.add(identifier)
        if tag == "h1":
            self.heading_count += 1
        if tag == "img":
            assert "alt" in attributes, "Image is missing alt text"
            assert "width" in attributes and "height" in attributes, "Image needs dimensions"
        if tag == "meta":
            self.metadata[attributes.get("name", attributes.get("property"))] = attributes.get("content")
        if tag == "link" and attributes.get("rel") == "canonical":
            self.canonical_url = attributes.get("href")
        if tag == "script" and attributes.get("type") == "application/ld+json":
            self.reading_structured_data = True

    def handle_endtag(self, tag):
        if tag == "script":
            self.reading_structured_data = False

    def handle_data(self, data):
        if self.reading_structured_data:
            self.structured_data += data


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
            if parsed_reference.fragment and referenced_path in documents:
                assert parsed_reference.fragment in documents[referenced_path].identifiers, f"Missing anchor: {reference}"

    homepage = documents[(website_directory / "index.html").resolve()]
    assert homepage.canonical_url == WEBSITE_URL, "Canonical URL differs from published URL"
    for metadata_name in ("description", "viewport", "og:title", "og:description", "og:image", "twitter:card"):
        assert homepage.metadata.get(metadata_name), f"Missing metadata: {metadata_name}"
    assert homepage.metadata["og:url"] == WEBSITE_URL
    assert homepage.metadata["og:image"] == WEBSITE_URL + "assets/social-preview.png"
    assert "noindex" not in homepage.metadata.get("robots", "")
    structured_data = json.loads(homepage.structured_data)
    assert structured_data["url"] == WEBSITE_URL
    assert structured_data["@type"] == "SoftwareApplication"
    assert structured_data["downloadUrl"] in homepage.references
    image_header = (website_directory / "assets/social-preview.png").read_bytes()[:24]
    assert image_header[:8] == b"\x89PNG\r\n\x1a\n", "Social card must be a PNG"
    assert struct.unpack(">II", image_header[16:24]) == (1200, 630), "Social card must be 1200 x 630"
    sitemap = ElementTree.parse(website_directory / "sitemap.xml")
    namespace = {"sitemap": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    assert sitemap.findtext("sitemap:url/sitemap:loc", namespaces=namespace) == WEBSITE_URL
    assert (website_directory / ".nojekyll").is_file()
    print(f"Website validation passed: {len(documents)} pages, local links, assets, anchors, metadata, JSON-LD, social card, sitemap.")
