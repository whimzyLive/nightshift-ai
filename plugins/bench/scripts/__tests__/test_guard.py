"""The push/PR guard, the quota preflight, and cleanup's read-only plan.

The guard replaced a blanket `git push` deny, so these are the tests that
justify that trade. Every one of them asks the same question: can a caller
talk this into allowing something outside the cell's own refs?
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bench_guard  # noqa: E402
import cleanup  # noqa: E402
import provision  # noqa: E402
from benchlib import quota  # noqa: E402

CELL_BRANCH = "bench/NA-68/sdlc@0.45.4/r1"
SCRATCH = "NA-201"


def _config(root):
    claude = Path(root) / ".claude"
    claude.mkdir(parents=True, exist_ok=True)
    (claude / "bench-guard.json").write_text(
        json.dumps(
            {
                "ticket": SCRATCH,
                "branch": CELL_BRANCH,
                "allowed_refs": provision.allowed_refs(SCRATCH, CELL_BRANCH),
            }
        )
    )
    return Path(root)


class TestRefAllowList(unittest.TestCase):
    def setUp(self):
        self.allowed = provision.allowed_refs(SCRATCH, CELL_BRANCH)

    def _ok(self, ref):
        return bench_guard.ref_allowed(ref, self.allowed)

    def test_cell_branch_allowed(self):
        self.assertTrue(self._ok(CELL_BRANCH))

    def test_sdlc_story_branch_for_this_scratch_key_allowed(self):
        self.assertTrue(self._ok("feat/" + SCRATCH))
        self.assertTrue(self._ok("fix/" + SCRATCH))

    def test_another_tickets_story_branch_refused(self):
        self.assertFalse(self._ok("feat/NA-999"))

    def test_protected_branches_refused(self):
        for ref in ("main", "master", "develop", "HEAD"):
            self.assertFalse(self._ok(ref), ref)

    def test_fully_qualified_ref_is_judged_the_same(self):
        # Otherwise `refs/heads/develop` slips past a short-form allow-list.
        self.assertFalse(self._ok("refs/heads/develop"))
        self.assertTrue(self._ok("refs/heads/" + CELL_BRANCH))

    def test_prefix_is_anchored_at_both_ends(self):
        # `bench/x` must not authorise `bench/x-evil` ... nor `evil-bench/x`.
        self.assertFalse(self._ok("evil-" + CELL_BRANCH))
        self.assertFalse(self._ok("feat/" + SCRATCH + "/../../develop"))


class TestGitPushChecks(unittest.TestCase):
    def setUp(self):
        self.root = _config(tempfile.mkdtemp())
        self.config = json.loads(
            (self.root / ".claude" / "bench-guard.json").read_text()
        )

    def _check(self, command):
        return bench_guard.check_command(command, str(self.root), self.config)

    def test_push_to_cell_branch_allowed(self):
        self.assertIsNone(
            self._check("git push origin " + CELL_BRANCH)
        )

    def test_push_to_develop_denied(self):
        reason = self._check("git push origin develop")
        self.assertIsNotNone(reason)
        self.assertIn("outside", reason)

    def test_refspec_destination_is_what_is_checked(self):
        # `src:dst` -- the destination is the ref that actually gets written,
        # so a benign-looking source must not launder a forbidden target.
        reason = self._check("git push origin " + CELL_BRANCH + ":develop")
        self.assertIsNotNone(reason)

    def test_force_push_denied_even_to_an_allowed_ref(self):
        for flag in ("--force", "-f", "--force-with-lease"):
            reason = self._check(
                "git push {0} origin {1}".format(flag, CELL_BRANCH)
            )
            self.assertIsNotNone(reason, flag)

    def test_delete_and_mirror_denied(self):
        self.assertIsNotNone(self._check("git push --delete origin " + CELL_BRANCH))
        self.assertIsNotNone(self._check("git push --mirror origin"))

    def test_chained_command_denied_rather_than_parsed(self):
        # `git status && git push origin develop` -- naive parsing sees the
        # first verb and waves the second through.
        reason = self._check("git status && git push origin develop")
        self.assertIsNotNone(reason)
        self.assertIn("chains", reason)

    def test_command_substitution_denied(self):
        self.assertIsNotNone(self._check("git push origin $(cat /tmp/ref)"))

    def test_merge_and_rebase_denied(self):
        self.assertIsNotNone(self._check("git merge develop"))
        self.assertIsNotNone(self._check("git rebase develop"))

    def test_ungoverned_git_commands_untouched(self):
        for command in ("git status", "git commit -m x", "git log --oneline"):
            self.assertIsNone(self._check(command), command)


class TestBarePushUsesCurrentBranch(unittest.TestCase):
    """A bare `git push` names no ref, so the ref is read from the worktree."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(
            ["git", "-C", str(self.root), "commit", "-q", "--allow-empty", "-m", "x"],
            check=True,
            env={"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                 "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
                 "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
        )
        _config(self.root)
        self.config = json.loads(
            (self.root / ".claude" / "bench-guard.json").read_text()
        )

    def _checkout(self, branch):
        subprocess.run(
            ["git", "-C", str(self.root), "checkout", "-q", "-B", branch], check=True
        )

    def test_bare_push_on_allowed_branch(self):
        self._checkout(CELL_BRANCH)
        self.assertIsNone(
            bench_guard.check_command("git push", str(self.root), self.config)
        )

    def test_bare_push_on_forbidden_branch_denied(self):
        self._checkout("develop")
        self.assertIsNotNone(
            bench_guard.check_command("git push", str(self.root), self.config)
        )

    def test_push_remote_only_also_resolves_current_branch(self):
        self._checkout("develop")
        self.assertIsNotNone(
            bench_guard.check_command("git push origin", str(self.root), self.config)
        )


class TestGhChecks(unittest.TestCase):
    def setUp(self):
        self.root = _config(tempfile.mkdtemp())
        self.config = json.loads(
            (self.root / ".claude" / "bench-guard.json").read_text()
        )

    def _check(self, command):
        return bench_guard.check_command(command, str(self.root), self.config)

    def test_pr_create_without_draft_denied_with_a_usable_reason(self):
        reason = self._check('gh pr create --title t --body b --base develop')
        self.assertIsNotNone(reason)
        # The reason is fed back to the model, so it must say what to do.
        self.assertIn("--draft", reason)

    def test_pr_create_with_draft_allowed(self):
        self.assertIsNone(
            self._check('gh pr create --draft --title t --body b --base develop')
        )
        self.assertIsNone(self._check('gh pr create -d --title t --body b'))

    def test_pr_ready_denied(self):
        # SDLC's playbook creates a PR then calls `gh pr ready` on it, which
        # would undo the draft the guard just enforced.
        self.assertIsNotNone(self._check("gh pr ready https://github.com/x/y/pull/1"))

    def test_pr_merge_denied(self):
        self.assertIsNotNone(self._check("gh pr merge 12 --squash"))

    def test_gh_api_merge_endpoint_denied(self):
        self.assertIsNotNone(
            self._check("gh api -X PUT repos/o/r/pulls/1/merge")
        )

    def test_ordinary_gh_reads_untouched(self):
        self.assertIsNone(self._check("gh pr view 12 --json state"))
        self.assertIsNone(self._check("gh pr list --state open"))


class TestGuardFailsClosed(unittest.TestCase):
    def test_missing_config_denies_a_governed_verb(self):
        root = Path(tempfile.mkdtemp())
        allowed, reason = bench_guard.evaluate(
            {"tool_name": "Bash", "cwd": str(root),
             "tool_input": {"command": "git push origin " + CELL_BRANCH}}
        )
        self.assertFalse(allowed)
        self.assertIn("no .claude/bench-guard.json", reason)

    def test_malformed_config_denies(self):
        root = Path(tempfile.mkdtemp())
        (root / ".claude").mkdir()
        (root / ".claude" / "bench-guard.json").write_text("{ not json")
        allowed, _ = bench_guard.evaluate(
            {"tool_name": "Bash", "cwd": str(root),
             "tool_input": {"command": "git push"}}
        )
        self.assertFalse(allowed)

    def test_config_without_allowed_refs_denies(self):
        root = Path(tempfile.mkdtemp())
        (root / ".claude").mkdir()
        (root / ".claude" / "bench-guard.json").write_text(json.dumps({"ticket": "x"}))
        allowed, _ = bench_guard.evaluate(
            {"tool_name": "Bash", "cwd": str(root),
             "tool_input": {"command": "git push"}}
        )
        self.assertFalse(allowed)

    def test_missing_config_does_not_block_ungoverned_commands(self):
        # A cell with a config problem must still be able to run `ls`; only
        # the guarded verbs are this hook's business.
        root = Path(tempfile.mkdtemp())
        allowed, _ = bench_guard.evaluate(
            {"tool_name": "Bash", "cwd": str(root),
             "tool_input": {"command": "pnpm nx run-many -t test"}}
        )
        self.assertTrue(allowed)

    def test_non_bash_tools_untouched(self):
        allowed, _ = bench_guard.evaluate(
            {"tool_name": "Write", "tool_input": {"file_path": "/x", "content": "git push"}}
        )
        self.assertTrue(allowed)

    def test_main_emits_a_deny_decision_on_stdout(self):
        root = Path(tempfile.mkdtemp())
        proc = subprocess.run(
            [sys.executable, str(Path(bench_guard.__file__))],
            input=json.dumps(
                {"tool_name": "Bash", "cwd": str(root),
                 "tool_input": {"command": "git push origin develop"}}
            ),
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0)
        payload = json.loads(proc.stdout)
        self.assertEqual(
            payload["hookSpecificOutput"]["permissionDecision"], "deny"
        )

    def test_main_is_silent_when_nothing_is_denied(self):
        proc = subprocess.run(
            [sys.executable, str(Path(bench_guard.__file__))],
            input=json.dumps(
                {"tool_name": "Bash", "tool_input": {"command": "ls"}}
            ),
            capture_output=True,
            text=True,
        )
        # Silence, not approval: normal permission rules still decide.
        self.assertEqual(proc.stdout.strip(), "")


class TestProvisionRegistersTheGuard(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.worktree = self.root / "wt"
        self.worktree.mkdir()

    def test_push_is_no_longer_blanket_denied(self):
        # The whole point of the guard: a blanket deny measures a blocked
        # session rather than an approach.
        self.assertNotIn("Bash(git push:*)", provision.BENCH_DENIED_PERMISSIONS)

    def test_merge_verbs_stay_denied_outright(self):
        for entry in (
            "Bash(git merge:*)",
            "Bash(git rebase:*)",
            "Bash(gh pr merge:*)",
            "Bash(gh pr ready:*)",
        ):
            self.assertIn(entry, provision.BENCH_DENIED_PERMISSIONS)

    def test_hook_registered_in_settings(self):
        path = provision.write_bench_settings(
            self.worktree,
            enabled_plugins={},
            extra_allow=[],
            guard_script=Path("/x/bench_guard.py"),
        )
        data = json.loads(Path(path).read_text())
        hook = data["hooks"]["PreToolUse"][0]
        self.assertEqual(hook["matcher"], "Bash")
        self.assertIn("bench_guard.py", hook["hooks"][0]["command"])

    def test_guard_config_written_with_this_cells_refs(self):
        path = provision.write_guard_config(
            self.worktree, SCRATCH, CELL_BRANCH, "sdlc@0.45.4"
        )
        data = json.loads(Path(path).read_text())
        self.assertEqual(data["ticket"], SCRATCH)
        self.assertTrue(
            bench_guard.ref_allowed(CELL_BRANCH, data["allowed_refs"])
        )
        self.assertFalse(bench_guard.ref_allowed("develop", data["allowed_refs"]))


class TestQuotaPreflight(unittest.TestCase):
    def test_small_sweep_proceeds(self):
        forecast = quota.preflight(2, per_cell_usd=1.0)
        self.assertEqual(forecast["estimated_usd"], 2.0)

    def test_expensive_sweep_needs_acknowledgement(self):
        with self.assertRaisesRegex(quota.QuotaGuardError, "acknowledge-cost"):
            quota.preflight(20, per_cell_usd=5.0, threshold_usd=25.0)

    def test_acknowledgement_clears_the_cost_gate(self):
        forecast = quota.preflight(
            20, acknowledged=True, per_cell_usd=5.0, threshold_usd=25.0
        )
        self.assertTrue(forecast["acknowledged"])

    def test_cell_cap_is_not_clearable_by_acknowledgement(self):
        # Acknowledging a number you did not intend to produce is not consent.
        with self.assertRaisesRegex(quota.QuotaGuardError, "ceiling"):
            quota.preflight(100, acknowledged=True, max_cells=24)

    def test_zero_cells_is_an_error_not_a_free_pass(self):
        with self.assertRaises(quota.QuotaGuardError):
            quota.preflight(0)

    def test_estimate_states_that_it_is_coarse(self):
        self.assertIn("coarse", quota.estimate(4)["basis"])

    def test_measured_cost_prefers_history_over_the_default(self):
        runs = [
            {"total": {"reported_cost_usd": 2.0}},
            {"total": {"reported_cost_usd": 4.0}},
        ]
        self.assertEqual(quota.measured_per_cell_usd(runs), 3.0)

    def test_no_history_returns_none_rather_than_zero(self):
        # Returning 0.0 would forecast a free sweep.
        self.assertIsNone(quota.measured_per_cell_usd([]))
        self.assertIsNone(quota.measured_per_cell_usd([{"total": {}}]))


class TestCleanupPlanIsReadOnly(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
               "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
               "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(
            ["git", "-C", str(self.root), "commit", "-q", "--allow-empty", "-m", "x"],
            check=True, env=env,
        )
        subprocess.run(
            ["git", "-C", str(self.root), "branch", "bench/NA-68/opus/r1"], check=True
        )
        subprocess.run(
            ["git", "-C", str(self.root), "branch", "feat/NA-68"], check=True
        )

    def test_finds_only_bench_branches_for_this_ticket(self):
        branches = cleanup.bench_branches(self.root, "NA-68")
        self.assertEqual(branches, ["bench/NA-68/opus/r1"])

    def test_does_not_claim_another_tickets_branches(self):
        self.assertEqual(cleanup.bench_branches(self.root, "NA-99"), [])

    def test_plan_leaves_everything_in_place(self):
        before = subprocess.run(
            ["git", "-C", str(self.root), "branch", "--list"],
            capture_output=True, text=True,
        ).stdout
        cleanup.plan(self.root, "NA-68", project="")
        after = subprocess.run(
            ["git", "-C", str(self.root), "branch", "--list"],
            capture_output=True, text=True,
        ).stdout
        self.assertEqual(before, after)

    def test_render_flags_a_pr_that_is_not_a_draft(self):
        text = cleanup.render_plan(
            {
                "ticket": "NA-68",
                "branches": [],
                "worktrees": [],
                "scratch_issues": [],
                "pull_requests": [{"number": 5, "title": "t", "isDraft": False}],
            }
        )
        self.assertIn("READY, not draft", text)


if __name__ == "__main__":
    unittest.main()


class TestZeroTurnAndUnknownCommandAreFailures(unittest.TestCase):
    """The NA-82 regression: a rejected prompt looked like a clean $0 success.

    `/sdlc:auto NA-83` returned subtype "success", is_error false, num_turns 0,
    duration 11ms, cost $0, result "Unknown command: /sdlc:auto". Every
    allow-listed field was clean, so the cell was recorded as a successful run
    and only the downstream empty-diff check noticed -- which reads as "this
    approach wrote no code", a claim about the approach rather than about a
    broken cell.
    """

    def _check(self, **payload):
        from benchlib import termination
        base = {"is_error": False, "subtype": "success"}
        base.update(payload)
        return termination.check_result_payload(base)

    def test_the_exact_na82_payload_is_not_clean(self):
        verdict = self._check(
            num_turns=0, duration_ms=11, total_cost_usd=0,
            result="Unknown command: /sdlc:auto",
        )
        self.assertFalse(verdict["clean"])
        joined = " ".join(verdict["violations"])
        self.assertIn("no turns", joined)
        self.assertIn("Unknown command", joined)

    def test_zero_turns_alone_is_a_violation(self):
        self.assertFalse(self._check(num_turns=0)["clean"])

    def test_unknown_command_alone_is_a_violation(self):
        verdict = self._check(num_turns=4, result="Unknown command: /nope")
        self.assertFalse(verdict["clean"])
        # The message must point at the fix, since this is an adapter bug.
        self.assertIn("plain language", " ".join(verdict["violations"]))

    def test_a_real_session_stays_clean(self):
        verdict = self._check(num_turns=37, result="Implemented the blog collection.")
        self.assertTrue(verdict["clean"], verdict["violations"])

    def test_missing_num_turns_is_not_invented_as_a_failure(self):
        # An older CLI that emitted no num_turns must not fail every cell.
        self.assertTrue(self._check(result="done")["clean"])


class TestSdlcAdaptersDoNotUseSlashSyntax(unittest.TestCase):
    def test_prompt_invokes_the_skill_by_name(self):
        from benchlib import adapters
        for name in ("sdlc-0.44.0.yaml", "sdlc-0.45.4.yaml"):
            with self.subTest(adapter=name):
                a = adapters.load_adapter(
                    Path(__file__).resolve().parents[2] / "approaches" / name
                )
                self.assertNotIn("/sdlc:auto", a.prompt)
                self.assertIn("sdlc:auto skill", a.prompt)
                self.assertIn("{{ticket_key}}", a.prompt)
