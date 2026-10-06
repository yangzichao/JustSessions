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
    def test_replacing_nested_stylesheet_without_updating_page_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            stylesheet_path = website_directory / "styles/comparison/comparison.css"
            stylesheet_path.write_text(stylesheet_path.read_text() + "\n/* changed */\n")
            with self.assertRaisesRegex(AssertionError, "Asset cache version mismatch: .*comparison.css"):
                validate_site(website_directory)

    def test_replacing_demo_video_without_updating_page_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            video_path = website_directory / "assets/multi-agent-sessions.mp4"
            video_path.write_bytes(video_path.read_bytes() + b"\0")
            with self.assertRaisesRegex(AssertionError, "Asset cache version mismatch: .*multi-agent-sessions"):
                validate_site(website_directory)

    def test_replacing_social_image_without_updating_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            social_image_path = website_directory / "assets/social-preview.png"
            social_image_path.write_bytes(social_image_path.read_bytes() + b"\0")
            with self.assertRaisesRegex(AssertionError, "Social image cache version mismatch"):
                validate_site(website_directory)

    def test_replacing_screenshot_without_updating_page_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            screenshot_path = website_directory / "assets/session-reader.jpg"
            screenshot_path.write_bytes(screenshot_path.read_bytes() + b"\0")
            with self.assertRaisesRegex(AssertionError, "Asset cache version mismatch: .*session-reader"):
                validate_site(website_directory)

    def test_replacing_gallery_script_without_updating_page_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            script_path = website_directory / "scripts/screenshot-gallery.js"
            script_path.write_text(script_path.read_text() + "\n// changed\n")
            with self.assertRaisesRegex(AssertionError, "Asset cache version mismatch: .*screenshot-gallery"):
                validate_site(website_directory)

    def test_replacing_imported_script_without_updating_parent_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            website_directory = Path(temporary_directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", website_directory):
                build_site()
            script_path = website_directory / "scripts/gallery-rotation.js"
            script_path.write_text(script_path.read_text() + "\n// changed\n")
            with self.assertRaisesRegex(AssertionError, "Script import cache version mismatch: .*gallery-rotation"):
                validate_site(website_directory)


if __name__ == "__main__":
    unittest.main()
