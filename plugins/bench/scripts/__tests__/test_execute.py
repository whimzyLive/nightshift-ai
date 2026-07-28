import json
import shlex
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

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


class TestDetectSimpleMode(unittest.TestCase):
    """Simple/bare mode never reads OAuth or the keychain, so it must be
    caught independently of key-based detection."""

    def test_env_var_set_is_simple_mode(self):
        reason = execute.detect_simple_mode({"CLAUDE_CODE_SIMPLE": "1"}, [])
        self.assertIsNotNone(reason)
        self.assertIn("CLAUDE_CODE_SIMPLE", reason)

    def test_empty_env_var_is_not_simple_mode(self):
        reason = execute.detect_simple_mode({"CLAUDE_CODE_SIMPLE": ""}, [])
        self.assertIsNone(reason)

    def test_bare_flag_is_simple_mode(self):
        reason = execute.detect_simple_mode({}, ["--bare"])
        self.assertIsNotNone(reason)
        self.assertIn("--bare", reason)

    def test_clean_env_and_flags_is_not_simple_mode(self):
        reason = execute.detect_simple_mode({}, ["--permission-mode", "acceptEdits"])
        self.assertIsNone(reason)


class TestBillingPreflight(unittest.TestCase):
    """CHANGE 2: a preflight guard that ABORTS before any hook or subprocess
    runs, rather than merely recording the basis after the fact.
    """

    def test_clean_subscription_env_does_not_raise(self):
        with TemporaryDirectory() as tmp:
            mode = execute.billing_preflight({}, [Path(tmp) / "missing.json"], [], False)
        self.assertEqual(mode["mode"], "subscription")

    def test_api_key_in_env_aborts(self):
        with self.assertRaises(execute.BillingGuardError) as ctx:
            execute.billing_preflight(
                {"ANTHROPIC_API_KEY": "sk-ant-SECRET"}, [], [], False
            )
        message = str(ctx.exception)
        self.assertIn("ANTHROPIC_API_KEY", message)
        self.assertNotIn("sk-ant-SECRET", message)
        self.assertIn("--allow-api-billing", message)

    def test_api_key_helper_in_settings_aborts(self):
        with TemporaryDirectory() as tmp:
            settings = Path(tmp) / "s.json"
            settings.write_text(json.dumps({"apiKeyHelper": "/bin/get-key"}))
            with self.assertRaises(execute.BillingGuardError) as ctx:
                execute.billing_preflight({}, [settings], [], False)
        self.assertIn("apiKeyHelper", str(ctx.exception))

    def test_simple_mode_env_var_aborts(self):
        with self.assertRaises(execute.BillingGuardError) as ctx:
            execute.billing_preflight({"CLAUDE_CODE_SIMPLE": "1"}, [], [], False)
        self.assertIn("CLAUDE_CODE_SIMPLE", str(ctx.exception))

    def test_bare_flag_aborts(self):
        with self.assertRaises(execute.BillingGuardError) as ctx:
            execute.billing_preflight({}, [], ["--bare"], False)
        self.assertIn("--bare", str(ctx.exception))

    def test_allow_api_billing_bypasses_abort_and_records_api(self):
        mode = execute.billing_preflight(
            {"ANTHROPIC_API_KEY": "sk-ant-SECRET"}, [], [], True
        )
        self.assertEqual(mode["mode"], "api")
        self.assertNotIn("sk-ant-SECRET", json.dumps(mode))

    def test_allow_api_billing_still_lets_a_clean_env_through_as_subscription(self):
        mode = execute.billing_preflight({}, [], [], True)
        self.assertEqual(mode["mode"], "subscription")

    def test_secret_never_appears_in_abort_message(self):
        secret = "sk-ant-DO-NOT-LEAK-THIS-EITHER"
        with TemporaryDirectory() as tmp:
            settings = Path(tmp) / "s.json"
            settings.write_text(json.dumps({"env": {"ANTHROPIC_API_KEY": secret}}))
            with self.assertRaises(execute.BillingGuardError) as ctx:
                execute.billing_preflight(
                    {"ANTHROPIC_API_KEY": secret}, [settings], [], False
                )
        self.assertNotIn(secret, str(ctx.exception))


def _write_adapter_yaml(path, flags=None, setup=None, teardown=None):
    flags = flags or []
    setup = setup or []
    teardown = teardown or []
    flags_literal = json.dumps(flags)
    setup_literal = json.dumps(setup)
    teardown_literal = json.dumps(teardown)
    path.write_text(
        "id: test-adapter\n"
        "label: Test Adapter\n"
        "setup: {0}\n"
        "run:\n"
        "  model: claude-opus-5\n"
        "  prompt: |\n"
        "    hello {{{{ticket_key}}}}\n"
        "  flags: {1}\n"
        "teardown: {2}\n".format(setup_literal, flags_literal, teardown_literal)
    )


class TestMainBillingPreflight(unittest.TestCase):
    """execute.main() must abort at preflight -- before adapter.setup hooks
    and before the `claude` subprocess -- for every API-billed or
    simple-mode condition, and must proceed (without invoking `claude`) on a
    clean subscription environment. Never invokes the real `claude` CLI.
    """

    def setUp(self):
        self.tmp = TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.artifacts = self.root / "artifacts"
        self.artifacts.mkdir()
        self.worktree = self.root / "worktree"
        self.worktree.mkdir()

        self.cell_path = self.root / "cell.json"
        self.cell_path.write_text(
            json.dumps(
                {
                    "repo": str(self.repo),
                    "worktree": str(self.worktree),
                    "artifacts": str(self.artifacts),
                }
            )
        )
        self.story_path = self.root / "story.json"
        self.story_path.write_text(
            json.dumps(
                {"key": "NA-1", "summary": "S", "description": "D", "acs": "- a"}
            )
        )
        self.adapter_path = self.root / "adapter.yaml"
        _write_adapter_yaml(self.adapter_path)
        self.out_path = self.root / "result.json"

        # Fake $HOME so a real ~/.claude/settings.json on the dev machine
        # never leaks into these tests.
        self.fake_home = self.root / "fake-home"
        self.fake_home.mkdir()

        # Neutralise anything genuinely set in this process's environment so
        # the tests are hermetic regardless of what machine runs them.
        self.env_patch = patch.dict(
            execute.os.environ,
            {
                "ANTHROPIC_API_KEY": "",
                "ANTHROPIC_AUTH_TOKEN": "",
                "CLAUDE_CODE_SIMPLE": "",
            },
        )
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        self.home_patch = patch.object(execute.Path, "home", return_value=self.fake_home)
        self.home_patch.start()
        self.addCleanup(self.home_patch.stop)

    def _argv(self, extra=None):
        argv = [
            "--cell",
            str(self.cell_path),
            "--story",
            str(self.story_path),
            "--adapter",
            str(self.adapter_path),
            "--out",
            str(self.out_path),
        ]
        return argv + (extra or [])

    def test_api_key_aborts_before_hooks_or_subprocess(self):
        """A test that would pass because something later blew up is not
        good enough: run_hooks and subprocess.run are wired to raise
        AssertionError if called, so if the guard did NOT stop the run at
        preflight, this test fails with the WRONG exception type, not with
        BillingGuardError.
        """
        with patch.dict(execute.os.environ, {"ANTHROPIC_API_KEY": "sk-ant-LIVE"}):
            with patch.object(
                execute, "run_hooks", side_effect=AssertionError("hooks must not run")
            ), patch.object(
                execute.subprocess,
                "run",
                side_effect=AssertionError("claude must not be invoked"),
            ):
                with self.assertRaises(execute.BillingGuardError) as ctx:
                    execute.main(self._argv())
        self.assertIn("ANTHROPIC_API_KEY", str(ctx.exception))
        self.assertNotIn("sk-ant-LIVE", str(ctx.exception))
        self.assertFalse(self.out_path.exists())

    def test_api_key_helper_in_settings_aborts_before_hooks_or_subprocess(self):
        claude_dir = self.repo / ".claude"
        claude_dir.mkdir()
        (claude_dir / "settings.json").write_text(
            json.dumps({"apiKeyHelper": "/bin/get-key"})
        )
        with patch.object(
            execute, "run_hooks", side_effect=AssertionError("hooks must not run")
        ), patch.object(
            execute.subprocess,
            "run",
            side_effect=AssertionError("claude must not be invoked"),
        ):
            with self.assertRaises(execute.BillingGuardError) as ctx:
                execute.main(self._argv())
        self.assertIn("apiKeyHelper", str(ctx.exception))
        self.assertFalse(self.out_path.exists())

    def test_simple_mode_env_var_aborts_before_hooks_or_subprocess(self):
        with patch.dict(execute.os.environ, {"CLAUDE_CODE_SIMPLE": "1"}):
            with patch.object(
                execute, "run_hooks", side_effect=AssertionError("hooks must not run")
            ), patch.object(
                execute.subprocess,
                "run",
                side_effect=AssertionError("claude must not be invoked"),
            ):
                with self.assertRaises(execute.BillingGuardError) as ctx:
                    execute.main(self._argv())
        self.assertIn("CLAUDE_CODE_SIMPLE", str(ctx.exception))
        self.assertFalse(self.out_path.exists())

    def test_clean_env_proceeds_past_preflight_without_invoking_claude(self):
        """Proceeding is proven two ways: the stubbed `claude` call is
        reached (mock_run gets called), and the real CLI is never invoked
        (subprocess.run is stubbed, so no real process is spawned)."""
        context_dir = self.repo / ".claude" / "project"
        context_dir.mkdir(parents=True)
        (context_dir / "project-context.md").write_text(
            "| Token | Value |\n"
            "| --- | --- |\n"
            "| Typecheck / Test | — / echo ok |\n"
        )
        fake_completed = type(
            "FakeCompletedProcess",
            (),
            {
                "returncode": 0,
                "stdout": json.dumps({"session_id": "sess-1", "total_cost_usd": 0.0}),
                "stderr": "",
            },
        )()
        with patch.object(
            execute.subprocess, "run", return_value=fake_completed
        ) as mock_run:
            code = execute.main(self._argv())
        self.assertEqual(code, 0)
        mock_run.assert_called_once()
        called_argv = mock_run.call_args[0][0]
        self.assertEqual(called_argv[0], "claude")
        result = json.loads(self.out_path.read_text())
        self.assertEqual(result["billing_mode"]["mode"], "subscription")

    def test_allow_api_billing_with_key_present_proceeds_and_records_api(self):
        context_dir = self.repo / ".claude" / "project"
        context_dir.mkdir(parents=True)
        (context_dir / "project-context.md").write_text(
            "| Token | Value |\n"
            "| --- | --- |\n"
            "| Typecheck / Test | — / echo ok |\n"
        )
        fake_completed = type(
            "FakeCompletedProcess",
            (),
            {
                "returncode": 0,
                "stdout": json.dumps({"session_id": "sess-2", "total_cost_usd": 0.0}),
                "stderr": "",
            },
        )()
        with patch.dict(execute.os.environ, {"ANTHROPIC_API_KEY": "sk-ant-LIVE"}):
            with patch.object(execute.subprocess, "run", return_value=fake_completed):
                code = execute.main(self._argv(["--allow-api-billing"]))
        self.assertEqual(code, 0)
        result = json.loads(self.out_path.read_text())
        self.assertEqual(result["billing_mode"]["mode"], "api")
        self.assertNotIn("sk-ant-LIVE", self.out_path.read_text())

    def test_planted_secret_never_reaches_result_json(self):
        context_dir = self.repo / ".claude" / "project"
        context_dir.mkdir(parents=True)
        (context_dir / "project-context.md").write_text(
            "| Token | Value |\n"
            "| --- | --- |\n"
            "| Typecheck / Test | — / echo ok |\n"
        )
        secret = "sk-ant-PLANTED-SECRET-VALUE"
        fake_completed = type(
            "FakeCompletedProcess",
            (),
            {
                "returncode": 0,
                "stdout": json.dumps({"session_id": "sess-3", "total_cost_usd": 0.0}),
                "stderr": "",
            },
        )()
        with patch.dict(execute.os.environ, {"ANTHROPIC_API_KEY": secret}):
            with patch.object(execute.subprocess, "run", return_value=fake_completed):
                code = execute.main(self._argv(["--allow-api-billing"]))
        self.assertEqual(code, 0)
        self.assertNotIn(secret, self.out_path.read_text())
