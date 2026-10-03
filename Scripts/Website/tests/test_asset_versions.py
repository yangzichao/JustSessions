"""Replacing a screenshot must invalidate its published image URL."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_site import build_site
from validate_site import validate_site


class ScreenshotCacheVersionTests(unittest.TestCase):
    def test_replacing_screenshot_without_updating_page_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            screenshot_path = website_directory / "assets/session-overview.jpg"
            screenshot_path.write_bytes(screenshot_path.read_bytes() + b"\0")
            with self.assertRaisesRegex(AssertionError, "Asset cache version mismatch: .*session-overview"):
                validate_site(website_directory)


if __name__ == "__main__":
    unittest.main()
