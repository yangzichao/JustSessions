"""Check the homepage's concise capability summary against the app."""

from html.parser import HTMLParser

SUMMARY_CAPABILITIES = ("preview", "delete", "ssh", "branch")


class HomepageCapabilityClaims(HTMLParser):
    def __init__(self):
        super().__init__()
        self.claims = {}

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        capability = attributes.get("data-capability")
        if capability is None:
            return
        assert capability in SUMMARY_CAPABILITIES, f"Unknown homepage capability: {capability}"
        assert capability not in self.claims, f"Repeated homepage capability: {capability}"
        self.claims[capability] = attributes.get("data-support")


def validate_homepage_capabilities(homepage_content, capabilities):
    parser = HomepageCapabilityClaims()
    parser.feed(homepage_content)
    assert set(parser.claims) == set(SUMMARY_CAPABILITIES), "Homepage capability claims are missing"
    for capability, claimed_support in parser.claims.items():
        supported_count = sum(provider[capability] for provider in capabilities.values())
        expected_support = "all" if supported_count == len(capabilities) else "some" if supported_count else "none"
        assert claimed_support == expected_support, f"App and documentation differ: homepage {capability}: {claimed_support}"
