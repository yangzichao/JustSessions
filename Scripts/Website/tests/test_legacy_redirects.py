"""Old Help and Feedback links must still reach the consolidated Guide."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_site import build_site
from validate_site import validate_site
from website_document import WebsiteDocument


class LegacyRedirectTests(unittest.TestCase):
    def test_old_urls_redirect_to_guide_and_stay_out_of_sitemap(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            sitemap = (website_directory / "sitemap.xml").read_text()
            for document_name, destination in (("help.html", "./guide.html"), ("feedback.html", "./guide.html#feedback")):
                with self.subTest(document_name=document_name):
                    document = WebsiteDocument()
                    document.feed((website_directory / document_name).read_text())
                    self.assertEqual(document.metadata["refresh"], f"0; url={destination}")
                    self.assertIn(destination, document.references)
                    self.assertIn("noindex", document.metadata["robots"])
                    self.assertNotIn(document_name, sitemap)

    def test_redirect_chain_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            help_page = website_directory / "help.html"
            help_page.write_text(help_page.read_text().replace(
                'content="0; url=./guide.html"', 'content="0; url=./feedback.html"',
            ))
            with self.assertRaisesRegex(AssertionError, "help.html must redirect directly to Guide"):
                validate_site(website_directory)


if __name__ == "__main__":
    unittest.main()
