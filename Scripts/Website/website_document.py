"""Read page metadata and references without a browser or third-party parser."""

from html.parser import HTMLParser


class WebsiteDocument(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.references = []
        self.identifiers = set()
        self.metadata = {}
        self.heading_count = 0
        self.language = None
        self.title = ""
        self.reading_title = False
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
        if tag == "html":
            self.language = attributes.get("lang")
        if tag == "title":
            self.reading_title = True
        if tag == "h1":
            self.heading_count += 1
        if tag == "img":
            assert "alt" in attributes, "Image is missing alt text"
            assert "width" in attributes and "height" in attributes, "Image needs dimensions"
        if tag == "meta":
            metadata_name = attributes.get("name", attributes.get("property"))
            if metadata_name:
                assert metadata_name not in self.metadata, f"Duplicate metadata: {metadata_name}"
                self.metadata[metadata_name] = attributes.get("content")
        if tag == "link" and attributes.get("rel") == "canonical":
            assert self.canonical_url is None, "Duplicate canonical URL"
            self.canonical_url = attributes.get("href")
        if tag == "script" and attributes.get("type") == "application/ld+json":
            self.reading_structured_data = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.reading_title = False
        if tag == "script":
            self.reading_structured_data = False

    def handle_data(self, data):
        if self.reading_title:
            self.title += data
        if self.reading_structured_data:
            self.structured_data += data
