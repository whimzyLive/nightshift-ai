import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import execute  # noqa: E402


class TestBuildVariables(unittest.TestCase):
    def test_maps_story_and_cell_fields(self):
        cell = {"worktree": "/w", "artifacts": "/a", "base_sha": "abc"}
        story = {"key": "NA-1", "summary": "S", "description": "D", "acs": "- a"}
        variables = execute.build_variables(cell, story, "pnpm test")
        self.assertEqual(variables["ticket_key"], "NA-1")
        self.assertEqual(variables["ticket_summary"], "S")
        self.assertEqual(variables["ticket_description"], "D")
        self.assertEqual(variables["ticket_acs"], "- a")
        self.assertEqual(variables["worktree"], "/w")
        self.assertEqual(variables["artifacts"], "/a")
        self.assertEqual(variables["test_command"], "pnpm test")


class TestClaudeArgv(unittest.TestCase):
    def test_always_prints_json(self):
        argv = execute.claude_argv([])
        self.assertIn("--print", argv)
        self.assertIn("--output-format", argv)
        self.assertIn("json", argv)

    def test_appends_adapter_flags(self):
        argv = execute.claude_argv(["--permission-mode", "acceptEdits"])
        self.assertIn("--permission-mode", argv)
        self.assertIn("acceptEdits", argv)

    def test_prompt_is_not_passed_as_an_argument(self):
        argv = execute.claude_argv([])
        self.assertNotIn("-p", argv)

    def test_never_bypasses_permissions(self):
        argv = execute.claude_argv([])
        self.assertNotIn("--dangerously-skip-permissions", argv)


if __name__ == "__main__":
    unittest.main()
