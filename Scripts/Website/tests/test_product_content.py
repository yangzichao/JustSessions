"""Capability changes and stale visible cells must block website publication."""

import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY_DIRECTORY = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_DIRECTORY / "Scripts/Website"))

from validate_product_content import validate_product_content


class ProductContentValidationTests(unittest.TestCase):
    def setUp(self):
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.repository_directory = Path(temporary_directory.name)
        for relative_path in (
            "README.md", "docs/guides/session-storage.md", "website/index.html", "website/guide.html",
            "Sources/JustSessions/Models/Conversations/ConversationProvider.swift",
            "Sources/JustSessions/Services/Transcript/TranscriptLoader.swift",
        ):
            target_path = self.repository_directory / relative_path
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPOSITORY_DIRECTORY / relative_path, target_path)

    def replace_first(self, relative_path, pattern, replacement):
        document_path = self.repository_directory / relative_path
        original_content = document_path.read_text()
        changed_content, replacement_count = re.subn(pattern, replacement, original_content, count=1, flags=re.MULTILINE)
        self.assertEqual(replacement_count, 1, "Test must change an actual capability claim")
        document_path.write_text(changed_content)

    def assert_stale_claim_rejected(self, location):
        with self.assertRaisesRegex(AssertionError, f"App and documentation differ: {location}"):
            validate_product_content(self.repository_directory)

    def test_stale_online_preview_claim_is_rejected(self):
        self.replace_first("website/guide.html", r'(<tr data-provider="[^\"]+">[^\n]+?</th><td>)Yes(</td>)', r'\1Not yet\2')
        self.assert_stale_claim_rejected("guide.html")

    def test_stale_homepage_preview_claim_is_rejected(self):
        self.replace_first("website/index.html", r'(data-capability="preview" data-support=")all(")', r'\1some\2')
        self.assert_stale_claim_rejected("homepage preview")

    def test_missing_homepage_claim_is_rejected(self):
        self.replace_first("website/index.html", r' data-capability="preview"', '')
        with self.assertRaisesRegex(AssertionError, "Homepage capability claims are missing"):
            validate_product_content(self.repository_directory)

    def test_stale_readme_preview_claim_is_rejected(self):
        self.replace_first("README.md", r'^(\| Read a conversation preview \| )Yes( \|)', r'\1Not yet\2')
        self.assert_stale_claim_rejected("README")

    def test_stale_storage_deletion_claim_is_rejected(self):
        self.replace_first("docs/guides/session-storage.md", r'^(\| Claude Code \|[^\n]+\| )Yes( \|)$', r'\1No\2')
        self.assert_stale_claim_rejected("storage guide")

    def test_app_preview_change_requires_matching_documentation(self):
        self.replace_first(
            "Sources/JustSessions/Services/Transcript/TranscriptLoader.swift",
            r'^\s*case \.\w+: try \w+TranscriptReader[^\n]*\n', '',
        )
        self.assert_stale_claim_rejected("guide.html")


if __name__ == "__main__":
    unittest.main()
