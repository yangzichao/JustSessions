"""Keep the pre-tag writing gate strict without rejecting specific, useful copy."""

import copy
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "ReleaseNotes"))

from catalog import load_catalog
from check_release_notes import check_release_notes
from prepare_release_notes import prepare_release_notes


class ReleaseNoteEditorialChecksTests(unittest.TestCase):
    def setUp(self):
        self.release = {
            "version": "2.0.0",
            "publishedOn": "2026-10-08",
            "title": {"en": "Conversation search", "zh-Hans": "对话搜索"},
            "sections": [{"kind": "fixed", "items": [{
                "en": "Improved performance when searching saved conversations.",
                "zh-Hans": "加快已保存对话的搜索速度。",
            }]}],
        }

    def load_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "releases.json"
            path.write_text(json.dumps([self.release]))
            return load_catalog(path)

    def test_specific_changes_and_exact_length_limits_are_accepted(self):
        self.assertEqual(self.load_fixture(), [self.release])
        self.release["title"] = {"en": "one two three four five six", "zh-Hans": "字" * 20}
        self.release["sections"][0]["items"][0] = {"en": " ".join(["word"] * 20), "zh-Hans": "字" * 60}
        self.assertEqual(self.load_fixture(), [self.release])

    def test_overlong_copy_is_rejected_in_both_languages(self):
        for field, language, value, message in (
            ("title", "en", "one two three four five six seven", "title: English copy exceeds 6"),
            ("title", "zh-Hans", "字" * 21, "title: Chinese copy exceeds 20"),
            ("bullet", "en", " ".join(["word"] * 21), "bullet 1: English copy exceeds 20"),
            ("bullet", "zh-Hans", "字" * 61, "bullet 1: Chinese copy exceeds 60"),
        ):
            with self.subTest(field=field, language=language):
                self.setUp()
                target = self.release["title"] if field == "title" else self.release["sections"][0]["items"][0]
                target[language] = value
                with self.assertRaisesRegex(ValueError, message):
                    self.load_fixture()

    def test_bullet_budget_applies_across_sections(self):
        for index in range(4):
            self.release["sections"][0]["items"].append({"en": f"Change {index}", "zh-Hans": f"变化 {index}"})
        self.load_fixture()
        self.release["sections"].append({"kind": "new", "items": [{"en": "Another change", "zh-Hans": "另一个变化"}]})
        with self.assertRaisesRegex(ValueError, "at most 5 bullets"):
            self.load_fixture()

    def test_filler_is_rejected_in_titles_and_bullets(self):
        for field in ("title", "bullet"):
            for language, value in (
                ("en", "We’re EXCITED about conversation search."),
                ("en", "We are  thrilled about search."),
                ("en", "A seamless search experience."),
                ("zh-Hans", "重磅推出对话搜索。"),
            ):
                with self.subTest(field=field, value=value):
                    self.setUp()
                    target = self.release["title"] if field == "title" else self.release["sections"][0]["items"][0]
                    target[language] = value
                    with self.assertRaisesRegex(ValueError, "Replace filler"):
                        self.load_fixture()

    def test_generic_claims_are_rejected(self):
        for language, value in (
            ("en", "Improved performance."),
            ("en", "Bug fixes and improvements."),
            ("en", "Performance and stability improvements."),
            ("en", "Minor bug fixes."),
            ("en", "Small fixes."),
            ("en", "Small bug fixes."),
            ("zh-Hans", "提升稳定性。"),
            ("zh-Hans", "修复了一些问题。"),
            ("zh-Hans", "修复了一些小问题。"),
        ):
            with self.subTest(value=value):
                self.setUp()
                self.release["sections"][0]["items"][0][language] = value
                with self.assertRaisesRegex(ValueError, "Name the affected feature"):
                    self.load_fixture()

    def test_small_fixes_bullet_groups_minor_fixes_last_under_fixed(self):
        small_fixes = {"en": "Small bug fixes.", "zh-Hans": "修复了一些小问题。"}
        self.release["sections"][0]["items"].append(small_fixes)
        self.load_fixture()
        self.release["sections"] = [{"kind": "fixed", "items": [small_fixes]}]
        self.load_fixture()

    def test_small_fixes_bullet_must_close_the_fixed_section(self):
        small_fixes = {"en": "Small bug fixes.", "zh-Hans": "修复了一些小问题。"}
        for sections in (
            [{"kind": "improved", "items": [small_fixes]}],
            [{"kind": "fixed", "items": [small_fixes, {"en": "Fixed freezes when reading images.", "zh-Hans": "修复读取图片时卡顿。"}]}],
        ):
            with self.subTest(sections=sections):
                self.release["sections"] = sections
                with self.assertRaisesRegex(ValueError, "last under Fixed"):
                    self.load_fixture()

    def test_repeated_changes_are_rejected_in_either_language(self):
        for language in ("en", "zh-Hans"):
            with self.subTest(language=language):
                self.setUp()
                first = self.release["sections"][0]["items"][0]
                second = {"en": "A different change.", "zh-Hans": "另一个变化。"}
                second[language] = first[language].upper().rstrip(".。")
                self.release["sections"].append({"kind": "new", "items": [second]})
                with self.assertRaisesRegex(ValueError, "Remove the repeated change"):
                    self.load_fixture()

    def test_style_failure_stops_publication_before_files_are_written(self):
        self.release["title"]["en"] = "A seamless search experience"
        with tempfile.TemporaryDirectory() as directory:
            output_directory = Path(directory) / "publication"
            with patch("prepare_release_notes.load_catalog", side_effect=self.load_fixture):
                with self.assertRaisesRegex(ValueError, "Replace filler"):
                    prepare_release_notes("v2.0.0", output_directory)
            self.assertFalse(output_directory.exists())

    def test_pre_tag_check_requires_newest_entry_and_previews_both_languages(self):
        older_release = copy.deepcopy(self.release)
        older_release["version"] = "1.0.0"
        with patch("check_release_notes.load_catalog", return_value=[self.release, older_release]):
            with self.assertRaisesRegex(ValueError, "must be the newest entry"):
                check_release_notes("v1.0.0")
            output = io.StringIO()
            with redirect_stdout(output):
                check_release_notes("v2.0.0")
            for value in self.release["sections"][0]["items"][0].values():
                self.assertIn(value, output.getvalue())
            self.assertIn("review each claim", output.getvalue())


if __name__ == "__main__":
    unittest.main()
