import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from forbidden_tracked_paths import find_forbidden_tracked_paths, forbidden_reason


class ForbiddenTrackedPathsTests(unittest.TestCase):
    def test_rejects_agent_skills_and_state(self):
        for tracked_path in [
            '.claude/skills/demo-video/SKILL.md',
            '.claude/settings.local.json',
            '.agents/skills/release/SKILL.md',
            '.codex/config.toml',
            '.cursor/rules/style.mdc',
            '.aider.chat.history.md',
            'CLAUDE.md',
            'website/CLAUDE.local.md',
        ]:
            with self.subTest(tracked_path=tracked_path):
                self.assertIsNotNone(forbidden_reason(tracked_path))

    def test_rejects_machine_local_output_at_any_depth(self):
        for tracked_path in ['default.profraw', 'Scripts/Website/__pycache__/build_site.cpython-313.pyc',
                             'Branding/.DS_Store', 'Cloudflare/Feedback/.wrangler/state.json', 'dist/JustSessions.app/Info.plist']:
            with self.subTest(tracked_path=tracked_path):
                self.assertIsNotNone(forbidden_reason(tracked_path))

    def test_allows_shared_project_files(self):
        for tracked_path in ['AGENTS.md', 'docs/development/demo-video.md', 'Scripts/DemoVideo/demo-video',
                             'Sources/JustSessions/Services/Transcript/ClaudeTranscriptReader.swift',
                             'Tests/JustSessionsTests/Adapters/Claude/ClaudeAdapterTests.swift', '.gitignore', '.github/workflows/release.yml']:
            with self.subTest(tracked_path=tracked_path):
                self.assertIsNone(forbidden_reason(tracked_path))

    def test_reports_only_violations_in_order(self):
        violations = find_forbidden_tracked_paths(['README.md', '.claude/skills/a/SKILL.md', 'Makefile', 'CLAUDE.md'])
        self.assertEqual([path for path, _ in violations], ['.claude/skills/a/SKILL.md', 'CLAUDE.md'])


if __name__ == '__main__':
    unittest.main()
