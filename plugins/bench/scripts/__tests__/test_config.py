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


class TestSplitCommandPair(unittest.TestCase):
    """The `Typecheck / Test` cell is a pair, not one command (finding C5)."""

    def test_em_dash_typecheck_yields_only_the_test_command(self):
        # This is verbatim what this repo's project-context.md carries.
        typecheck, test = config.split_command_pair("— / pnpm nx run-many -t test")
        self.assertEqual(typecheck, "")
        self.assertEqual(test, "pnpm nx run-many -t test")

    def test_both_sides_present(self):
        typecheck, test = config.split_command_pair("pnpm typecheck / pnpm test")
        self.assertEqual(typecheck, "pnpm typecheck")
        self.assertEqual(test, "pnpm test")

    def test_em_dash_test_side_yields_empty_test_command(self):
        typecheck, test = config.split_command_pair("pnpm typecheck / —")
        self.assertEqual(typecheck, "pnpm typecheck")
        self.assertEqual(test, "")

    def test_single_value_with_no_separator_is_the_test_command(self):
        typecheck, test = config.split_command_pair("pnpm nx run-many -t test")
        self.assertEqual(typecheck, "")
        self.assertEqual(test, "pnpm nx run-many -t test")

    def test_empty_cell(self):
        self.assertEqual(config.split_command_pair(""), ("", ""))

    def test_separator_inside_the_test_command_is_kept(self):
        # Only the FIRST " / " separates the pair.
        typecheck, test = config.split_command_pair("tsc / sh -c 'a / b'")
        self.assertEqual(typecheck, "tsc")
        self.assertEqual(test, "sh -c 'a / b'")


class TestRequireCommand(unittest.TestCase):
    def test_accepts_a_real_command(self):
        self.assertEqual(
            config.require_command("pnpm nx run-many -t test", "test"),
            "pnpm nx run-many -t test",
        )

    def test_rejects_empty(self):
        with self.assertRaises(config.InvalidCommandError):
            config.require_command("", "test")

    def test_rejects_the_unsplit_pair_string(self):
        # The exact garbage the pre-fix code would have run.
        with self.assertRaises(config.InvalidCommandError):
            config.require_command("— / pnpm nx run-many -t test", "test")

    def test_rejects_a_bare_dash_placeholder(self):
        with self.assertRaises(config.InvalidCommandError):
            config.require_command("—", "test")

    def test_rejects_multiline(self):
        with self.assertRaises(config.InvalidCommandError):
            config.require_command("pnpm test\nrm -rf /", "test")


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

    def test_splits_the_typecheck_test_pair_from_this_repos_real_row(self):
        repo = self._repo_with_context(
            SAMPLE.replace(
                "| Typecheck / Test | pnpm nx run-many -t test     |",
                "| Typecheck / Test | — / pnpm nx run-many -t test |",
            )
        )
        cfg = config.load_config(repo, {})
        self.assertEqual(cfg.typecheck_command, "")
        self.assertEqual(cfg.test_command, "pnpm nx run-many -t test")
        # The unsplit cell must never reach a caller.
        self.assertNotIn("—", cfg.test_command)

    def test_test_command_override_wins(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {"test_command": "make check"})
        self.assertEqual(cfg.test_command, "make check")


if __name__ == "__main__":
    unittest.main()
