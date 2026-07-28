import json
import shlex
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

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
        argv = execute.claude_argv([], "claude-opus-5")
        self.assertIn("--print", argv)
        self.assertIn("--output-format", argv)
        self.assertIn("json", argv)

    def test_appends_adapter_flags(self):
        argv = execute.claude_argv(["--permission-mode", "acceptEdits"], "claude-opus-5")
        self.assertIn("--permission-mode", argv)
        self.assertIn("acceptEdits", argv)

    def test_prompt_is_not_passed_as_an_argument(self):
        argv = execute.claude_argv([], "claude-opus-5")
        self.assertNotIn("-p", argv)

    def test_never_bypasses_permissions(self):
        argv = execute.claude_argv([], "claude-opus-5")
        self.assertNotIn("--dangerously-skip-permissions", argv)


class TestRenderHook(unittest.TestCase):
    def test_escapes_semicolon_command_injection_in_summary(self):
        """Summary with ; rm -rf should be rendered as a literal string, not shell syntax."""
        template = "echo {{ticket_summary}}"
        variables = {
            "ticket_key": "NA-2",
            "ticket_summary": "S; rm -rf /tmp/pwned #",
            "ticket_description": "D",
            "ticket_acs": "",
            "worktree": "/w",
            "artifacts": "/a",
            "base_branch": "",
            "test_command": "test",
        }
        rendered = execute.render_hook(template, variables)
        # shlex.quote() wraps dangerous text in single quotes
        self.assertIn("'S; rm -rf /tmp/pwned #'", rendered)
        # When parsed by shell, the dangerous text appears as one literal argument
        parsed = shlex.split(rendered)
        self.assertIn("S; rm -rf /tmp/pwned #", parsed)

    def test_escapes_backticks_in_description(self):
        """Description with backticks and $(...) should not be evaluated."""
        template = "echo {{ticket_description}}"
        variables = {
            "ticket_key": "NA-3",
            "ticket_summary": "S",
            "ticket_description": "D `whoami` $(echo pwned)",
            "ticket_acs": "",
            "worktree": "/w",
            "artifacts": "/a",
            "base_branch": "",
            "test_command": "test",
        }
        rendered = execute.render_hook(template, variables)
        # shlex.quote() wraps dangerous text in single quotes
        self.assertIn("'D `whoami` $(echo pwned)'", rendered)
        # Dangerous text should be one literal argument when parsed
        parsed = shlex.split(rendered)
        self.assertIn("D `whoami` $(echo pwned)", parsed)

    def test_escapes_newline_and_multiline_injection_in_acs(self):
        """ACS with newline followed by command should be literal."""
        template = "echo {{ticket_acs}}"
        variables = {
            "ticket_key": "NA-4",
            "ticket_summary": "S",
            "ticket_description": "D",
            "ticket_acs": "- a\nrm -rf /tmp/x",
            "worktree": "/w",
            "artifacts": "/a",
            "base_branch": "",
            "test_command": "test",
        }
        rendered = execute.render_hook(template, variables)
        # shlex.quote() wraps dangerous text including newlines in single quotes
        self.assertIn("'- a", rendered)  # Quoted text starts
        self.assertIn("rm -rf /tmp/x'", rendered)  # Quoted text ends after newline
        # The newline and second command should appear as one literal argument
        parsed = shlex.split(rendered)
        self.assertIn("- a\nrm -rf /tmp/x", parsed)

    def test_benign_hook_with_multiple_variables_still_works(self):
        """Normal hooks with worktree and test_command should still render usably."""
        template = "cd {{worktree}} && {{test_command}}"
        variables = {
            "ticket_key": "NA-5",
            "ticket_summary": "S",
            "ticket_description": "D",
            "ticket_acs": "",
            "worktree": "/home/user/work",
            "artifacts": "/tmp/artifacts",
            "base_branch": "main",
            "test_command": "pnpm test",
        }
        rendered = execute.render_hook(template, variables)
        # Should contain both variables
        self.assertIn("/home/user/work", rendered)
        self.assertIn("pnpm test", rendered)
        # Should be a valid shell command
        parsed = shlex.split(rendered)
        self.assertIn("cd", parsed)
        self.assertIn("&&", parsed)

    def test_unused_variables_do_not_cause_error(self):
        """Variables not referenced in the template should not cause issues."""
        template = "echo {{ticket_key}}"
        variables = {
            "ticket_key": "NA-6",
            "ticket_summary": "unused",
            "ticket_description": "unused",
            "ticket_acs": "unused",
            "worktree": "unused",
            "artifacts": "unused",
            "base_branch": "unused",
            "test_command": "unused",
        }
        rendered = execute.render_hook(template, variables)
        self.assertEqual(rendered, "echo NA-6")

    def test_all_eight_variables_can_be_rendered(self):
        """All 8 variables should be substitutable."""
        template = "{{ticket_key}} {{ticket_summary}} {{ticket_description}} {{ticket_acs}} {{worktree}} {{artifacts}} {{base_branch}} {{test_command}}"
        variables = {
            "ticket_key": "KEY",
            "ticket_summary": "SUMM",
            "ticket_description": "DESC",
            "ticket_acs": "ACS",
            "worktree": "WORK",
            "artifacts": "ART",
            "base_branch": "BASE",
            "test_command": "TEST",
        }
        rendered = execute.render_hook(template, variables)
        self.assertIn("KEY", rendered)
        self.assertIn("SUMM", rendered)
        self.assertIn("DESC", rendered)
        self.assertIn("ACS", rendered)
        self.assertIn("WORK", rendered)
        self.assertIn("ART", rendered)
        self.assertIn("BASE", rendered)
        self.assertIn("TEST", rendered)


if __name__ == "__main__":
    unittest.main()


class TestClaudeArgvModel(unittest.TestCase):
    """execute must pass --model, or the row measures the operator's default (C4)."""

    def test_model_is_passed(self):
        argv = execute.claude_argv([], "claude-opus-5")
        self.assertIn("--model", argv)
        self.assertEqual(argv[argv.index("--model") + 1], "claude-opus-5")

    def test_adapter_flags_still_follow(self):
        argv = execute.claude_argv(["--permission-mode", "acceptEdits"], "claude-opus-5")
        self.assertEqual(argv[-2:], ["--permission-mode", "acceptEdits"])
        self.assertIn("--model", argv)


class TestDetectBillingMode(unittest.TestCase):
    """CHANGE 1: the run must record WHICH basis its cost figures sit on.

    On a subscription there is no per-run charge, so `total_cost_usd` is an
    API-list-price equivalent, not spend. A sweep can be run on another
    machine, or after someone exports a key, so this has to be recorded per
    run rather than asserted once in a doc.
    """

    def _settings(self, tmp, name, payload):
        path = Path(tmp) / name
        path.write_text(json.dumps(payload))
        return path

    def test_no_key_anywhere_is_subscription(self):
        with TemporaryDirectory() as tmp:
            settings = self._settings(tmp, "s.json", {"env": {}})
            mode = execute.detect_billing_mode({}, [settings])
        self.assertEqual(mode["mode"], "subscription")
        self.assertIsNone(mode["api_key_env_var"])
        self.assertEqual(mode["settings_evidence"], [])

    def test_anthropic_api_key_env_var_is_api(self):
        with TemporaryDirectory() as tmp:
            settings = self._settings(tmp, "s.json", {})
            mode = execute.detect_billing_mode(
                {"ANTHROPIC_API_KEY": "sk-ant-SUPERSECRET"}, [settings]
            )
        self.assertEqual(mode["mode"], "api")
        self.assertEqual(mode["api_key_env_var"], "ANTHROPIC_API_KEY")

    def test_anthropic_auth_token_env_var_is_api(self):
        mode = execute.detect_billing_mode({"ANTHROPIC_AUTH_TOKEN": "tok-SECRET"}, [])
        self.assertEqual(mode["mode"], "api")
        self.assertEqual(mode["api_key_env_var"], "ANTHROPIC_AUTH_TOKEN")

    def test_empty_env_var_is_not_treated_as_a_key(self):
        mode = execute.detect_billing_mode({"ANTHROPIC_API_KEY": ""}, [])
        self.assertEqual(mode["mode"], "subscription")

    def test_api_key_helper_in_settings_is_api(self):
        with TemporaryDirectory() as tmp:
            settings = self._settings(tmp, "s.json", {"apiKeyHelper": "/bin/get-key"})
            mode = execute.detect_billing_mode({}, [settings])
        self.assertEqual(mode["mode"], "api")
        self.assertTrue(any("apiKeyHelper" in e for e in mode["settings_evidence"]))

    def test_env_anthropic_api_key_in_settings_is_api(self):
        with TemporaryDirectory() as tmp:
            settings = self._settings(
                tmp, "s.json", {"env": {"ANTHROPIC_API_KEY": "sk-ant-SECRET"}}
            )
            mode = execute.detect_billing_mode({}, [settings])
        self.assertEqual(mode["mode"], "api")
        self.assertTrue(
            any("env.ANTHROPIC_API_KEY" in e for e in mode["settings_evidence"])
        )

    def test_missing_or_malformed_settings_file_does_not_crash(self):
        with TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            bad.write_text("{not json")
            missing = Path(tmp) / "nope.json"
            mode = execute.detect_billing_mode({}, [bad, missing])
        self.assertEqual(mode["mode"], "subscription")

    def test_never_records_the_secret_value(self):
        """The whole point: presence and variable NAME only, never the value."""
        secret = "sk-ant-DO-NOT-LEAK-THIS"
        with TemporaryDirectory() as tmp:
            settings = self._settings(
                tmp, "s.json", {"env": {"ANTHROPIC_API_KEY": secret}}
            )
            mode = execute.detect_billing_mode(
                {"ANTHROPIC_API_KEY": secret, "ANTHROPIC_AUTH_TOKEN": secret},
                [settings],
            )
        serialised = json.dumps(mode)
        self.assertNotIn(secret, serialised)
        self.assertNotIn("sk-ant", serialised)

    def test_evidence_is_a_human_readable_sentence(self):
        mode = execute.detect_billing_mode({"ANTHROPIC_API_KEY": "x"}, [])
        self.assertIn("ANTHROPIC_API_KEY", mode["evidence"])
        subscription = execute.detect_billing_mode({}, [])
        self.assertIn("subscription", subscription["evidence"].lower())
