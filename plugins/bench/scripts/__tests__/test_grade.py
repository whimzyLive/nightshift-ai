import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import grade  # noqa: E402

DIFF = """diff --git a/src/app.ts b/src/app.ts
index 111..222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -1 +1 @@
-old
+new
diff --git a/docs/superpowers/plans/2026-01-01-thing.md b/docs/superpowers/plans/2026-01-01-thing.md
index 333..444 100644
--- a/docs/superpowers/plans/2026-01-01-thing.md
+++ b/docs/superpowers/plans/2026-01-01-thing.md
@@ -1 +1 @@
-a
+b
"""


class TestFilterDiff(unittest.TestCase):
    def test_keeps_source_files(self):
        self.assertIn("src/app.ts", grade.filter_diff(DIFF))

    def test_drops_plan_docs(self):
        self.assertNotIn("docs/superpowers/plans", grade.filter_diff(DIFF))

    def test_drops_spec_docs(self):
        diff = "diff --git a/docs/superpowers/specs/x.md b/docs/superpowers/specs/x.md\n+a\n"
        self.assertEqual(grade.filter_diff(diff).strip(), "")

    def test_drops_speckit_directory(self):
        diff = "diff --git a/.specify/memory.md b/.specify/memory.md\n+a\n"
        self.assertEqual(grade.filter_diff(diff).strip(), "")

    def test_strips_session_trailer(self):
        diff = "diff --git a/a.ts b/a.ts\n+Claude-Session: https://claude.ai/code/session_x\n+real\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("Claude-Session", out)
        self.assertIn("real", out)


class TestCellHash(unittest.TestCase):
    def test_is_stable(self):
        cell = {"ticket": "NA-1", "approach": "opus", "run_id": "r1"}
        self.assertEqual(grade.cell_hash(cell), grade.cell_hash(dict(cell)))

    def test_does_not_leak_the_approach_name(self):
        cell = {"ticket": "NA-1", "approach": "sdlc", "run_id": "r1"}
        self.assertNotIn("sdlc", grade.cell_hash(cell))


class TestReduceVerdicts(unittest.TestCase):
    def test_majority_wins_for_booleans(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])

    def test_records_disagreement(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["disagreement"])

    def test_unanimous_is_not_disagreement(self):
        verdicts = [{"acs": [{"id": "AC1", "met": True}]}] * 3
        reduced = grade.reduce_verdicts(verdicts)
        self.assertFalse(reduced["acs"]["AC1"]["disagreement"])

    def test_findings_count_uses_median(self):
        verdicts = [
            {"acs": [], "findings": [1, 2, 3]},
            {"acs": [], "findings": [1]},
            {"acs": [], "findings": [1, 2]},
        ]
        self.assertEqual(grade.reduce_verdicts(verdicts)["findings_count"], 2)


class TestGraderPrompt(unittest.TestCase):
    """grader_prompt is the whole blinding mechanism: everything the grader can
    see must be inlined into the returned string, never left as a path for the
    grader to go read (and potentially escape) on disk."""

    def test_inlines_acs_diff_and_tests(self):
        prompt = grade.grader_prompt("AC1: does the thing", "diff --git a/x b/x", "3 passed")
        self.assertIn("AC1: does the thing", prompt)
        self.assertIn("diff --git a/x b/x", prompt)
        self.assertIn("3 passed", prompt)

    def test_instructs_grader_not_to_speculate_on_provenance(self):
        prompt = grade.grader_prompt("acs", "diff", "tests")
        self.assertIn("do not know how it was produced", prompt.lower())

    def test_requests_json_only_reply(self):
        prompt = grade.grader_prompt("acs", "diff", "tests")
        self.assertIn("JSON object", prompt)
        self.assertIn('"acs"', prompt)


class TestBuildBlindDir(unittest.TestCase):
    """Exercises build_blind_dir against a disposable git repository created
    in a temp directory. All git operations run only against that throwaway
    repo, never against the real nightshift checkout."""

    def _run_git(self, repo: Path, *args: str) -> None:
        subprocess.run(
            ["git", "-C", str(repo)] + list(args),
            check=True,
            capture_output=True,
            text=True,
        )

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.repo = Path(self._tmp.name) / "throwaway-repo"
        self.repo.mkdir()

        self._run_git(self.repo, "init", "-q")
        self._run_git(self.repo, "config", "user.email", "bench@example.com")
        self._run_git(self.repo, "config", "user.name", "bench")

        (self.repo / "src").mkdir()
        (self.repo / "src" / "app.ts").write_text("old\n")
        (self.repo / "docs" / "superpowers" / "plans").mkdir(parents=True)
        (self.repo / "docs" / "superpowers" / "plans" / "plan.md").write_text("a\n")
        self._run_git(self.repo, "add", ".")
        self._run_git(self.repo, "commit", "-q", "-m", "base")
        self.base_sha = subprocess.run(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()

        (self.repo / "src" / "app.ts").write_text("new\n")
        (self.repo / "docs" / "superpowers" / "plans" / "plan.md").write_text("b\n")
        self._run_git(self.repo, "add", ".")
        self._run_git(self.repo, "commit", "-q", "-m", "change")

        self.artifacts = Path(self._tmp.name) / "artifacts"
        self.artifacts.mkdir()
        (self.artifacts / "tests.txt").write_text("2 passed\n")

        self.cell = {
            "ticket": "NA-1",
            "approach": "sdlc",
            "run_id": "r1",
            "worktree": str(self.repo),
            "base_sha": self.base_sha,
            "artifacts": str(self.artifacts),
            "repo": str(self.repo),
        }
        self.story = {"acs": "AC1: app.ts is updated"}
        self.blind_base = Path(self._tmp.name) / "blind"

    def test_target_dir_is_named_by_cell_hash(self):
        target = grade.build_blind_dir(self.cell, self.story, self.blind_base)
        self.assertEqual(target.name, grade.cell_hash(self.cell))

    def test_diff_patch_is_filtered(self):
        target = grade.build_blind_dir(self.cell, self.story, self.blind_base)
        diff_text = (target / "diff.patch").read_text()
        self.assertIn("src/app.ts", diff_text)
        self.assertNotIn("docs/superpowers/plans", diff_text)

    def test_acs_and_tests_are_written(self):
        target = grade.build_blind_dir(self.cell, self.story, self.blind_base)
        self.assertEqual((target / "acs.md").read_text(), "AC1: app.ts is updated")
        self.assertEqual((target / "tests.txt").read_text(), "2 passed\n")

    def test_missing_tests_file_falls_back_to_not_run(self):
        empty_artifacts = Path(self._tmp.name) / "no-tests-artifacts"
        empty_artifacts.mkdir()
        cell = dict(self.cell, artifacts=str(empty_artifacts), run_id="r2")
        target = grade.build_blind_dir(cell, self.story, self.blind_base)
        self.assertEqual((target / "tests.txt").read_text(), "not run")

    def test_full_blind_dir_path_has_no_approach_segment(self):
        """FINDING 1 end-to-end: build_blind_dir under blind_base_dir(cell)
        (repo + ticket only) must never surface the approach anywhere in the
        resolved path."""
        base = grade.blind_base_dir(self.cell)
        target = grade.build_blind_dir(self.cell, self.story, base)
        self.assertNotIn(self.cell["approach"], str(target))


# ---------------------------------------------------------------------------
# Fix round 1 findings
# ---------------------------------------------------------------------------


class TestBlindBaseDir(unittest.TestCase):
    """FINDING 1 (Critical): blind_dir must never contain the approach
    anywhere in its path — a grader can recover it via a bare `pwd` or an
    `ls ..`, no traversal required."""

    def test_path_never_contains_approach_for_any_known_approach(self):
        for approach in ("opus", "sdlc", "superpowers", "speckit"):
            with self.subTest(approach=approach):
                cell = {"ticket": "NA-1", "approach": approach, "run_id": "r1", "repo": "/repo"}
                self.assertNotIn(approach, str(grade.blind_base_dir(cell)))

    def test_path_is_keyed_by_repo_and_ticket_only(self):
        cell = {"ticket": "NA-42", "approach": "opus", "run_id": "r1", "repo": "/repo"}
        self.assertEqual(
            grade.blind_base_dir(cell),
            Path("/repo") / "docs" / "benchmarks" / "NA-42" / "blind",
        )


class TestFilterDiffApproachRedaction(unittest.TestCase):
    """FINDING 2 (Important): path-only filtering doesn't stop an approach
    naming itself in diff content (a comment, a branch reference). Content
    must be redacted too, without deleting lines."""

    def test_redacts_approach_id_word_in_added_line(self):
        diff = (
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+// implemented per sdlc approach\n"
        )
        out = grade.filter_diff(diff)
        self.assertNotIn("sdlc", out)
        self.assertIn("[REDACTED]", out)

    def test_redacts_branch_reference(self):
        diff = (
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+// branch bench/NA-1/sdlc/r1\n"
        )
        out = grade.filter_diff(diff)
        self.assertNotIn("bench/NA-1/sdlc/r1", out)
        self.assertIn("[REDACTED]", out)

    def test_redacts_bare_id_for_redacted_approaches(self):
        # opus is NOT in this list — it is a deliberate, documented
        # exception (see round-2 tests below).
        for approach in ("sdlc", "superpowers", "speckit"):
            with self.subTest(approach=approach):
                diff = "diff --git a/src/app.ts b/src/app.ts\n+// {0} did this\n".format(approach)
                out = grade.filter_diff(diff)
                self.assertNotIn(approach, out)

    def test_does_not_redact_substring_matches(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// corpus of tests\n"
        out = grade.filter_diff(diff)
        self.assertIn("corpus", out)
        self.assertNotIn("[REDACTED]", out)

    def test_does_not_redact_superpowered(self):
        # "superpowered" must survive even though it shares a long prefix
        # with the redacted approach id "superpowers".
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// a superpowered widget\n"
        out = grade.filter_diff(diff)
        self.assertIn("superpowered", out)
        self.assertNotIn("[REDACTED]", out)

    def test_preserves_line_count_of_kept_section(self):
        diff = (
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1,2 +1,2 @@\n"
            "-old\n"
            "-sdlc reference\n"
            "+new\n"
            "+still here\n"
        )
        out_lines = grade.filter_diff(diff).splitlines()
        in_lines = diff.splitlines()
        self.assertEqual(len(out_lines), len(in_lines))


class TestFilterDiffSpeckitAliases(unittest.TestCase):
    """Fix round 2 (Important): the bare id `speckit` isn't the form a model
    actually writes. `spec-kit` is the approach's real product name (it
    appears in this repo's own adapter label, "GitHub spec-kit"), and
    `specify-cli` is the CLI the adapter installs — both uniquely identify
    the approach and must be redacted too, alongside `spec kit`."""

    def test_redacts_hyphenated_spec_kit(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// built with GitHub spec-kit\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("spec-kit", out)
        self.assertIn("[REDACTED]", out)

    def test_redacts_spaced_spec_kit(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// used the spec kit workflow\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("spec kit", out)
        self.assertIn("[REDACTED]", out)

    def test_redacts_specify_cli(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// ran specify-cli init\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("specify-cli", out)
        self.assertIn("[REDACTED]", out)

    def test_redacts_bare_speckit_still(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// speckit did this\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("speckit", out)
        self.assertIn("[REDACTED]", out)

    def test_case_insensitive(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// Built with Spec-Kit\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("Spec-Kit", out)
        self.assertIn("[REDACTED]", out)


class TestFilterDiffOpusExceptionDocumented(unittest.TestCase):
    """Fix round 2: `opus` is a deliberate, documented exception to content
    redaction — the bare model name is left alone because model ids show up
    in code/config for reasons unrelated to which approach ran, and
    redacting it would mangle legitimate content."""

    def test_bare_opus_survives_content_redaction(self):
        diff = "diff --git a/src/app.ts b/src/app.ts\n+// uses claude-opus-4 under the hood\n"
        out = grade.filter_diff(diff)
        self.assertIn("opus", out)
        self.assertNotIn("[REDACTED]", out)

    def test_opus_not_in_alias_table(self):
        self.assertNotIn("opus", grade.APPROACH_REDACTION_ALIASES)


class TestFilterDiffQuotedPaths(unittest.TestCase):
    """FINDING 6 (Minor): git quotes headers for paths needing escaping
    (e.g. spaces). The plain regex silently fails to match those, leaving
    `keeping` stuck on the previous section's decision instead of resetting."""

    def test_quoted_stripped_path_does_not_leak(self):
        diff = (
            'diff --git "a/docs/superpowers/plans/file with space.md" '
            '"b/docs/superpowers/plans/file with space.md"\n'
            "index 111..222 100644\n"
            '--- "a/docs/superpowers/plans/file with space.md"\n'
            '+++ "b/docs/superpowers/plans/file with space.md"\n'
            "@@ -1 +1 @@\n"
            "-a\n"
            "+b\n"
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+new\n"
        )
        out = grade.filter_diff(diff)
        self.assertNotIn("docs/superpowers/plans", out)
        self.assertIn("src/app.ts", out)

    def test_quoted_path_does_not_leak_state_into_next_file(self):
        diff = (
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+new\n"
            'diff --git "a/docs/superpowers/plans/file with space.md" '
            '"b/docs/superpowers/plans/file with space.md"\n'
            "@@ -1 +1 @@\n"
            "-a\n"
            "+b\n"
        )
        out = grade.filter_diff(diff)
        self.assertIn("src/app.ts", out)
        self.assertNotIn("docs/superpowers/plans", out)


class TestCellHashSalt(unittest.TestCase):
    """FINDING 3 (Important): cell_hash is documented as de-identification,
    not preimage resistance. Optional cell["salt"] is folded in opportunistically
    (cheap defense in depth), with no-salt behaviour unchanged."""

    def test_salt_changes_the_hash_when_present(self):
        cell = {"ticket": "NA-1", "approach": "opus", "run_id": "r1"}
        salted = dict(cell, salt="abc123")
        self.assertNotEqual(grade.cell_hash(cell), grade.cell_hash(salted))

    def test_missing_salt_is_backward_compatible_with_explicit_empty_salt(self):
        cell = {"ticket": "NA-1", "approach": "opus", "run_id": "r1"}
        explicit_empty = dict(cell, salt="")
        self.assertEqual(grade.cell_hash(cell), grade.cell_hash(explicit_empty))


class TestReduceVerdictsRelativeMajority(unittest.TestCase):
    """FINDING 4 (Important): majority must be relative to votes actually
    cast for a given AC, not to len(verdicts) — otherwise an AC only one
    grader mentions is always reduced to False."""

    def test_single_verdict_met_true_is_not_overturned(self):
        verdicts = [{"acs": [{"id": "AC1", "met": True}]}]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])
        self.assertFalse(reduced["acs"]["AC1"]["disagreement"])

    def test_two_agreeing_verdicts(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])
        self.assertFalse(reduced["acs"]["AC1"]["disagreement"])

    def test_two_split_verdicts_tie_breaks_to_not_met(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertFalse(reduced["acs"]["AC1"]["met"])
        self.assertTrue(reduced["acs"]["AC1"]["disagreement"])

    def test_three_verdicts_majority_still_works(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])

    def test_ac_mentioned_by_only_one_of_three_graders_uses_its_own_votes(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC2", "met": True}]},
            {"acs": [{"id": "AC2", "met": True}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])  # 1/1 votes, not 1/3
        self.assertTrue(reduced["acs"]["AC2"]["met"])  # 2/2 votes

    def test_different_ac_id_sets_do_not_cross_contaminate(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}, {"id": "AC2", "met": True}]},
            {"acs": [{"id": "AC2", "met": False}]},
            {"acs": [{"id": "AC3", "met": True}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])  # 1/1
        self.assertFalse(reduced["acs"]["AC2"]["met"])  # 1 vs 1 -> tie -> False
        self.assertTrue(reduced["acs"]["AC3"]["met"])  # 1/1

    def test_regressions_flag_uses_relative_majority_too(self):
        # Only 2 verdicts (degraded path from collect_verdicts): the old
        # hardcoded `>= 2` denominator-of-3 check would have required both
        # to agree even on a 2-verdict cell. 1 True / 1 False must tie to False.
        reduced = grade.reduce_verdicts(
            [{"acs": [], "regressions": True}, {"acs": [], "regressions": False}]
        )
        self.assertFalse(reduced["regressions"])


class TestCollectVerdicts(unittest.TestCase):
    """FINDING 5 (Important): one bad grader must not kill the whole cell.
    Retries a failing grader once; proceeds if a majority succeeded; records
    failures; raises loudly if fewer than a majority succeeded. Uses a
    stubbed grader_fn — never invokes the real `claude` CLI."""

    @staticmethod
    def _stub(outcomes):
        it = iter(outcomes)

        def grader_fn(blind_dir, acs):
            outcome = next(it)
            if isinstance(outcome, Exception):
                raise outcome
            return outcome

        return grader_fn

    def test_all_graders_succeed(self):
        outcomes = [{"acs": []}] * 3
        result = grade.collect_verdicts(Path("/x"), "acs", 3, grader_fn=self._stub(outcomes))
        self.assertEqual(len(result["verdicts"]), 3)
        self.assertEqual(result["failures"], [])

    def test_one_failure_then_retry_succeeds(self):
        outcomes = [
            RuntimeError("flaky"), {"acs": []},  # grader 1: fails, then retry succeeds
            {"acs": []},                          # grader 2
            {"acs": []},                          # grader 3
        ]
        result = grade.collect_verdicts(Path("/x"), "acs", 3, grader_fn=self._stub(outcomes))
        self.assertEqual(len(result["verdicts"]), 3)
        self.assertEqual(result["failures"], [])

    def test_one_grader_fails_both_attempts_but_two_succeed(self):
        outcomes = [
            RuntimeError("boom"), RuntimeError("boom again"),  # grader 1: fails twice
            {"acs": []},                                        # grader 2
            {"acs": []},                                        # grader 3
        ]
        result = grade.collect_verdicts(Path("/x"), "acs", 3, grader_fn=self._stub(outcomes))
        self.assertEqual(len(result["verdicts"]), 2)
        self.assertEqual(len(result["failures"]), 1)
        self.assertIn("boom again", result["failures"][0])

    def test_only_one_grader_succeeds_raises(self):
        outcomes = [
            RuntimeError("boom"), RuntimeError("boom again"),
            RuntimeError("boom"), RuntimeError("boom again"),
            {"acs": []},
        ]
        with self.assertRaises(RuntimeError):
            grade.collect_verdicts(Path("/x"), "acs", 3, grader_fn=self._stub(outcomes))


if __name__ == "__main__":
    unittest.main()
