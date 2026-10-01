"""Read visible capability cells, including text inside inline code tags."""

from html.parser import HTMLParser


class CapabilityTable(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = {}
        self.provider_identifier = None
        self.reading_cell = False
        self.reading_command = False
        self.commands = {}

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == "tr" and "data-provider" in attributes:
            self.provider_identifier = attributes["data-provider"]
            assert self.provider_identifier not in self.rows, "Repeated capability row"
            self.rows[self.provider_identifier] = []
            self.commands[self.provider_identifier] = ""
        if self.provider_identifier and tag in ("th", "td"):
            self.rows[self.provider_identifier].append("")
            self.reading_cell = True
        if self.provider_identifier and tag == "code" and len(self.rows[self.provider_identifier]) == 1:
            self.reading_command = True

    def handle_endtag(self, tag):
        if tag in ("th", "td"):
            self.reading_cell = False
        if tag == "code":
            self.reading_command = False
        if tag == "tr":
            self.provider_identifier = None

    def handle_data(self, data):
        if self.provider_identifier and self.reading_cell:
            self.rows[self.provider_identifier][-1] += data
        if self.provider_identifier and self.reading_command:
            self.commands[self.provider_identifier] += data
