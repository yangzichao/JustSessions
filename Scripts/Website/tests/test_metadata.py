"""Reject metadata drift that would publish misleading search or share previews."""

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_site import build_site
from validate_site import validate_site


class MetadataConsistencyTests(unittest.TestCase):
    def setUp(self):
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.website_directory = Path(temporary_directory.name)
        with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", self.website_directory):
            build_site()

    def update_structured_data(self, property_name, value):
        homepage_path = self.website_directory / "index.html"
        homepage_content = homepage_path.read_text()
        structured_match = re.search(r'<script type="application/ld\+json">(.*?)</script>', homepage_content, re.DOTALL)
        structured_data = json.loads(structured_match.group(1))
        structured_data[property_name] = value
        homepage_path.write_text(
            homepage_content[:structured_match.start(1)]
            + json.dumps(structured_data)
            + homepage_content[structured_match.end(1):]
        )

    def test_old_structured_description_is_rejected(self):
        self.update_structured_data("description", "An outdated app description.")
        with self.assertRaisesRegex(AssertionError, "Structured app description differs"):
            validate_site(self.website_directory)

    def test_structured_screenshot_not_shown_on_page_is_rejected(self):
        self.update_structured_data("screenshot", ["https://yangzichao.github.io/JustSessions/assets/old-screenshot.jpg"])
        with self.assertRaisesRegex(AssertionError, "Structured app screenshot is missing"):
            validate_site(self.website_directory)

    def test_social_image_alt_text_disagreement_is_rejected(self):
        homepage_path = self.website_directory / "index.html"
        homepage_path.write_text(re.sub(
            r'(<meta name="twitter:image:alt" content=")[^"]+',
            r'\1An older social card.',
            homepage_path.read_text(),
        ))
        with self.assertRaisesRegex(AssertionError, "Social image alt text differs"):
            validate_site(self.website_directory)


if __name__ == "__main__":
    unittest.main()
