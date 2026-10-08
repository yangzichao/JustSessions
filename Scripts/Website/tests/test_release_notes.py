"""Protect editorial history, publication gates, and shared rendering."""

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_site import build_site
from catalog import load_catalog, release_for_tag
from prepare_release_notes import prepare_release_notes
from render_notes import render_sparkle_html, render_website_history


class ReleaseNotesTests(unittest.TestCase):
    def test_all_published_notes_appear_on_the_built_website(self):
        with tempfile.TemporaryDirectory() as directory:
            output_directory = Path(directory)
            with patch("build_site.WEBSITE_OUTPUT_DIRECTORY", output_directory):
                build_site()
            page = (output_directory / "release-notes.html").read_text()
            for release in load_catalog():
                self.assertIn(f'id="v{release["version"]}"', page)
                self.assertIn(release["title"]["en"], page)
            self.assertEqual(page.count('class="release-latest"'), 1)
            self.assertIn('href="./release-notes.html" aria-current="page"', page)
            self.assertIn("release-notes.html", (output_directory / "sitemap.xml").read_text())

    def test_missing_version_stops_publication_before_writing_files(self):
        with tempfile.TemporaryDirectory() as directory:
            output_directory = Path(directory) / "notes"
            with self.assertRaisesRegex(ValueError, "Add curated release notes"):
                prepare_release_notes("v999.0.0", output_directory)
            self.assertFalse(output_directory.exists())

    def test_github_and_sparkle_receive_the_selected_versions_changes(self):
        releases = load_catalog()
        selected = release_for_tag(releases, "v1.0.8")
        with tempfile.TemporaryDirectory() as directory:
            output_directory = Path(directory)
            prepare_release_notes("v1.0.8", output_directory)
            markdown = (output_directory / "release-notes.md").read_text()
            html = (output_directory / "JustSessions.html").read_text()
            self.assertIn(selected["title"]["en"], markdown)
            self.assertIn(selected["title"]["en"], html)
            self.assertNotIn(releases[0]["title"]["en"], markdown)
            self.assertNotIn(releases[0]["title"]["en"], html)
            for section in selected["sections"]:
                for item in section["items"]:
                    self.assertIn(item["en"], markdown)
                    self.assertIn(item["en"], html)

    def test_editorial_text_cannot_inject_html(self):
        release = copy.deepcopy(load_catalog()[0])
        release["title"]["en"] = '<script>alert("test")</script>'
        release["sections"][0]["items"][0]["en"] = '<img src=x onerror="alert(1)">'
        for output in (render_website_history([release]), render_sparkle_html(release)):
            self.assertNotIn("<script>", output)
            self.assertNotIn("<img ", output)
            self.assertIn("&lt;script&gt;", output)

    def test_duplicate_versions_missing_translations_and_invalid_dates_are_rejected(self):
        catalog = load_catalog()
        invalid_catalogs = [catalog + [catalog[-1]], copy.deepcopy(catalog), copy.deepcopy(catalog)]
        invalid_catalogs[1][0]["title"].pop("zh-Hans")
        invalid_catalogs[2][0]["publishedOn"] = "2026-02-30"
        for invalid_catalog in invalid_catalogs:
            with self.subTest(catalog=invalid_catalog[0]["version"]), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "releases.json"
                path.write_text(json.dumps(invalid_catalog))
                with self.assertRaises(ValueError):
                    load_catalog(path)


if __name__ == "__main__":
    unittest.main()
