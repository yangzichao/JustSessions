"""Every page must show the same top bar and footer, built from website/partials/."""

import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_site import WEBSITE_SOURCE_DIRECTORY, build_site
from shared_partials import PAGES_WITH_SHARED_PARTIALS, validate_partial_placeholders

SHARED_MARKUP_PATTERNS = {
    "top bar": re.compile(r'<a class="skip-link".*?</header>', re.DOTALL),
    "footer": re.compile(r"<footer.*?</footer>", re.DOTALL),
}
ASSET_VERSION_PATTERN = re.compile(r"\?v=[0-9a-f]{12}")


def built_markup(website_directory, document_name, pattern):
    matches = pattern.findall((website_directory / document_name).read_text())
    assert len(matches) == 1, f"Expected one match for {pattern.pattern} in {document_name}"
    return matches[0]


class SharedPartialTests(unittest.TestCase):
    def test_built_pages_share_one_top_bar_and_footer(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            for readable_name, pattern in SHARED_MARKUP_PATTERNS.items():
                with self.subTest(readable_name):
                    markup = {name: built_markup(website_directory, name, pattern) for name in PAGES_WITH_SHARED_PARTIALS}
                    comparable_markup = {ASSET_VERSION_PATTERN.sub("", value.replace(' aria-current="page"', "")) for value in markup.values()}
                    self.assertEqual(len(comparable_markup), 1)
                    self.assertNotIn("aria-current", markup["index.html"])
                    self.assertIn('href="./guide.html" aria-current="page"', markup["guide.html"])

    def test_page_with_its_own_top_bar_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_directory = Path(temporary_directory)
            for document_name in PAGES_WITH_SHARED_PARTIALS:
                shutil.copy2(WEBSITE_SOURCE_DIRECTORY / document_name, source_directory / document_name)
            guide_path = source_directory / "guide.html"
            guide_path.write_text(guide_path.read_text().replace(
                "<!-- partial: site-header -->",
                '<header class="site-header page-width"><a href="./">JustSessions</a></header>',
            ))
            with self.assertRaisesRegex(AssertionError, "guide.html must include the shared top bar exactly once"):
                validate_partial_placeholders(source_directory)


if __name__ == "__main__":
    unittest.main()
