import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import config  # noqa: E402

SAMPLE = """
# Project Context

| Token            | Value                        |
| ---------------- | ---------------------------- |
| Project name     | nightshift-ai                |
| Jira project key | NA                           |
| Jira site        | whimzylive.atlassian.net     |
| Base branch      | develop                      |
| Package manager  | pnpm                         |
| Typecheck / Test | pnpm nx run-many -t test     |
"""


class TestParseProjectContext(unittest.TestCase):
    def test_extracts_known_tokens(self):
        parsed = config.parse_project_context(SAMPLE)
        self.assertEqual(parsed["Jira site"], "whimzylive.atlassian.net")
        self.assertEqual(parsed["Jira project key"], "NA")
        self.assertEqual(parsed["Base branch"], "develop")
        self.assertEqual(parsed["Typecheck / Test"], "pnpm nx run-many -t test")

    def test_ignores_table_separator_rows(self):
        parsed = config.parse_project_context(SAMPLE)
        self.assertNotIn("----------------", parsed)
        self.assertNotIn("Token", parsed)

    def test_scopes_to_token_value_table_only(self):
        """Ensure only Token/Value config table is harvested, not other tables."""
        mixed = """
# Project Context

| Token            | Value                        |
| ---------------- | ---------------------------- |
| Jira site        | whimzylive.atlassian.net     |
| Base branch      | develop                      |

# Workspace Ownership

| Path             | Owner                        |
| ---------------- | ---------------------------- |
| Base branch      | some-engineer                |
| plugins/         | ai-enablement-engineer       |
"""
        parsed = config.parse_project_context(mixed)
        # Config table values should be present
        self.assertEqual(parsed["Jira site"], "whimzylive.atlassian.net")
        self.assertEqual(parsed["Base branch"], "develop")
        # Other table's keys should not be present
        self.assertNotIn("Path", parsed)
        self.assertNotIn("Owner", parsed)
        self.assertNotIn("plugins/", parsed)


class TestLoadConfig(unittest.TestCase):
    def _repo_with_context(self, text):
        tmp = Path(tempfile.mkdtemp())
        ctx = tmp / ".claude" / "project"
        ctx.mkdir(parents=True)
        (ctx / "project-context.md").write_text(text)
        return tmp

    def test_reads_from_project_context(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {})
        self.assertEqual(cfg.jira_site, "whimzylive.atlassian.net")
        self.assertEqual(cfg.jira_project, "NA")
        self.assertEqual(cfg.base_branch, "develop")

    def test_overrides_beat_project_context(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {"base_branch": "release"})
        self.assertEqual(cfg.base_branch, "release")

    def test_defaults_apply_without_project_context(self):
        tmp = Path(tempfile.mkdtemp())
        cfg = config.load_config(tmp, {})
        self.assertEqual(cfg.base_branch, "main")
        self.assertEqual(cfg.story_points_field, "customfield_10016")

    def test_story_points_field_is_not_discoverable_so_defaults(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {})
        self.assertEqual(cfg.story_points_field, "customfield_10016")


if __name__ == "__main__":
    unittest.main()
