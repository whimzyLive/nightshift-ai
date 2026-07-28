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
        prompt = grade.grader_prompt("AC1: does the thing", "diff --git a/x b/x", "3 passed", ["AC1"])
        self.assertIn("AC1: does the thing", prompt)
        self.assertIn("diff --git a/x b/x", prompt)
        self.assertIn("3 passed", prompt)

    def test_instructs_grader_not_to_speculate_on_provenance(self):
        prompt = grade.grader_prompt("acs", "diff", "tests", ["AC1"])
        self.assertIn("do not know how it was produced", prompt.lower())

    def test_requests_json_only_reply(self):
        prompt = grade.grader_prompt("acs", "diff", "tests", ["AC1"])
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
        # acs.md carries the harness-numbered criteria (finding I3), with the
        # author's hand-written "AC1:" prefix replaced by our own id.
        self.assertEqual((target / "acs.md").read_text(), "AC1. app.ts is updated")
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

    def test_path_is_outside_every_repository(self):
        """Finding I1: the blind dir must not sit inside the repo under
        grading -- a grader rooted there can `ls ..` the sibling cell
        directories AND loads the repo's CLAUDE.md / .claude/ config."""
        cell = {"ticket": "NA-42", "approach": "opus", "run_id": "r1", "repo": "/repo"}
        base = grade.blind_base_dir(cell)
        self.assertNotIn("/repo", str(base))
        self.assertNotIn("docs/benchmarks", str(base))
        self.assertTrue(base.is_absolute())
        self.assertTrue(base.exists())

    def test_each_call_yields_a_fresh_isolated_directory(self):
        cell = {"ticket": "NA-42", "approach": "opus", "run_id": "r1", "repo": "/repo"}
        self.assertNotEqual(grade.blind_base_dir(cell), grade.blind_base_dir(cell))

    def test_isolated_dir_has_no_sibling_cell_directories(self):
        cell = {"ticket": "NA-42", "approach": "opus", "run_id": "r1", "repo": "/repo"}
        base = grade.blind_base_dir(cell)
        self.assertEqual(list(base.iterdir()), [])


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

        def grader_fn(blind_dir, acs, ac_ids=None):
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


# ---------------------------------------------------------------------------
# Final whole-branch review findings: I1, I2, I3
# ---------------------------------------------------------------------------


class TestProcessArtifactStripping(unittest.TestCase):
    """Presence of a process file is a perfect tell (finding I2)."""

    def _diff_for(self, path):
        return (
            "diff --git a/{0} b/{0}\n"
            "--- a/{0}\n"
            "+++ b/{0}\n"
            "@@ -0,0 +1 @@\n"
            "+some content\n"
        ).format(path)

    def test_strips_superpowers_progress_files(self):
        out = grade.filter_diff(self._diff_for(".superpowers/sdd/2026-01-01-x/progress.md"))
        self.assertNotIn("some content", out)
        self.assertNotIn(".superpowers", out)

    def test_strips_plan_documents_anywhere(self):
        for path in (
            "docs/plans/my-plan.md",
            "PLAN.md",
            "notes/implementation-plan.md",
            "docs/plan/step1.md",
        ):
            with self.subTest(path=path):
                out = grade.filter_diff(self._diff_for(path))
                self.assertNotIn("some content", out, path)

    def test_strips_adr_directory(self):
        out = grade.filter_diff(self._diff_for("docs/adr/0001-use-x.md"))
        self.assertNotIn("some content", out)

    def test_strips_claude_config_directory(self):
        out = grade.filter_diff(self._diff_for(".claude/settings.json"))
        self.assertNotIn("some content", out)

    def test_strips_agents_directory(self):
        out = grade.filter_diff(self._diff_for(".agents/product-marketing.md"))
        self.assertNotIn("some content", out)

    def test_still_keeps_ordinary_source_files(self):
        out = grade.filter_diff(self._diff_for("src/planner.ts"))
        self.assertIn("some content", out)

    def test_keeps_a_source_file_that_merely_mentions_plan(self):
        # `plan` inside a .ts filename is not a process artifact.
        out = grade.filter_diff(self._diff_for("src/lib/plan-utils.ts"))
        self.assertIn("some content", out)


class TestNumberAcceptanceCriteria(unittest.TestCase):
    """AC ids come from the harness, not the grader (finding I3)."""

    def test_numbers_top_level_bullets_sequentially(self):
        text, ids = grade.number_acceptance_criteria("- one\n- two\n- three")
        self.assertEqual(ids, ["AC1", "AC2", "AC3"])
        self.assertEqual(text, "AC1. one\nAC2. two\nAC3. three")

    def test_nested_sub_bullets_are_not_separate_criteria(self):
        text, ids = grade.number_acceptance_criteria("- Top A\n  - Sub A1\n- Top B")
        self.assertEqual(ids, ["AC1", "AC2"])
        self.assertIn("  - Sub A1", text)

    def test_prose_lines_are_numbered_when_there_are_no_bullets(self):
        text, ids = grade.number_acceptance_criteria("does the thing\ndoes the other thing")
        self.assertEqual(ids, ["AC1", "AC2"])
        self.assertTrue(text.startswith("AC1. does the thing"))

    def test_existing_hand_written_ids_are_replaced_not_doubled(self):
        text, ids = grade.number_acceptance_criteria("- AC1: alpha\n- AC7: beta")
        self.assertEqual(ids, ["AC1", "AC2"])
        self.assertEqual(text, "AC1. alpha\nAC2. beta")

    def test_ids_are_stable_across_calls(self):
        acs = "- a\n- b"
        self.assertEqual(
            grade.number_acceptance_criteria(acs)[1],
            grade.number_acceptance_criteria(acs)[1],
        )

    def test_prompt_names_the_allowed_ids_and_forbids_others(self):
        prompt = grade.grader_prompt("AC1. a\nAC2. b", "diff", "tests", ["AC1", "AC2"])
        self.assertIn("AC1, AC2", prompt)
        self.assertIn("invent ids", prompt)


class TestValidateVerdict(unittest.TestCase):
    """One malformed grader must not discard the others (finding I3)."""

    ALLOWED = ["AC1", "AC2"]

    def test_accepts_a_well_formed_verdict(self):
        v = grade.validate_verdict(
            {"acs": [{"id": "AC1", "met": True, "evidence": "x"}], "findings": [],
             "regressions": False, "first_fix_round_items": 0},
            self.ALLOWED,
        )
        self.assertEqual(v["acs"][0]["id"], "AC1")

    def test_rejects_an_entry_with_no_id(self):
        # Pre-fix this KeyError'd out of reduce_verdicts and discarded all
        # three paid grader calls.
        with self.assertRaises(ValueError):
            grade.validate_verdict({"acs": [{"met": True}]}, self.ALLOWED)

    def test_rejects_acs_that_is_a_string(self):
        with self.assertRaises(ValueError) as ctx:
            grade.validate_verdict({"acs": "none"}, self.ALLOWED)
        self.assertIn("not a list", str(ctx.exception))

    def test_rejects_an_unknown_ac_id(self):
        with self.assertRaises(ValueError) as ctx:
            grade.validate_verdict({"acs": [{"id": "AC9", "met": True}]}, self.ALLOWED)
        self.assertIn("AC9", str(ctx.exception))

    def test_rejects_duplicate_ids(self):
        with self.assertRaises(ValueError):
            grade.validate_verdict(
                {"acs": [{"id": "AC1", "met": True}, {"id": "AC1", "met": False}]},
                self.ALLOWED,
            )

    def test_rejects_a_non_object_payload(self):
        with self.assertRaises(ValueError):
            grade.validate_verdict(["not", "an", "object"], self.ALLOWED)

    def test_rejects_non_numeric_first_fix_round_items(self):
        with self.assertRaises(ValueError):
            grade.validate_verdict(
                {"acs": [], "first_fix_round_items": "lots"}, self.ALLOWED
            )

    def test_missing_optional_fields_default_safely(self):
        v = grade.validate_verdict({"acs": []}, self.ALLOWED)
        self.assertEqual(v["findings"], [])
        self.assertFalse(v["regressions"])
        self.assertEqual(v["first_fix_round_items"], 0)


class TestOneBadGraderDoesNotDiscardTheOthers(unittest.TestCase):
    @staticmethod
    def _stub(outcomes):
        it = iter(outcomes)

        def grader_fn(blind_dir, acs, ac_ids=None):
            outcome = next(it)
            if isinstance(outcome, Exception):
                raise outcome
            return outcome

        return grader_fn

    def test_malformed_verdict_is_retried_then_only_it_is_discarded(self):
        good = {"acs": [{"id": "AC1", "met": True}]}
        outcomes = [
            {"acs": "none"}, {"acs": "none"},  # grader 1: malformed twice
            good,                              # grader 2
            good,                              # grader 3
        ]
        result = grade.collect_verdicts(
            Path("/x"), "acs", 3, grader_fn=self._stub(outcomes), ac_ids=["AC1"]
        )
        self.assertEqual(len(result["verdicts"]), 2)
        self.assertEqual(len(result["failures"]), 1)
        self.assertIn("not a list", result["failures"][0])

    def test_unknown_id_verdict_is_rerequested(self):
        good = {"acs": [{"id": "AC1", "met": True}]}
        outcomes = [
            {"acs": [{"id": "CRITERION-A", "met": True}]}, good,  # grader 1 recovers
            good,
            good,
        ]
        result = grade.collect_verdicts(
            Path("/x"), "acs", 3, grader_fn=self._stub(outcomes), ac_ids=["AC1"]
        )
        self.assertEqual(len(result["verdicts"]), 3)
        self.assertEqual(result["failures"], [])


class TestComparableAcDenominator(unittest.TestCase):
    def test_every_harness_id_appears_even_if_no_grader_mentioned_it(self):
        verdicts = [{"acs": [{"id": "AC1", "met": True}]}]
        reduced = grade.reduce_verdicts(verdicts, ac_ids=["AC1", "AC2", "AC3"])
        self.assertEqual(sorted(reduced["acs"]), ["AC1", "AC2", "AC3"])
        # An unmentioned criterion is not-met, never silently dropped.
        self.assertFalse(reduced["acs"]["AC2"]["met"])
        self.assertEqual(reduced["acs"]["AC2"]["votes"], [])

    def test_denominator_is_identical_for_two_approaches(self):
        ids = ["AC1", "AC2", "AC3"]
        a = grade.reduce_verdicts([{"acs": [{"id": "AC1", "met": True}]}], ac_ids=ids)
        b = grade.reduce_verdicts(
            [{"acs": [{"id": i, "met": True} for i in ids]}], ac_ids=ids
        )
        self.assertEqual(len(a["acs"]), len(b["acs"]))

    def test_reduce_survives_a_malformed_verdict_that_slipped_through(self):
        verdicts = [{"acs": "none"}, {"acs": [{"id": "AC1", "met": True}]}, {"acs": [{}]}]
        reduced = grade.reduce_verdicts(verdicts, ac_ids=["AC1"])
        self.assertTrue(reduced["acs"]["AC1"]["met"])


class TestArchiveBlindInputs(unittest.TestCase):
    """The grader runs from temp; the record lives with the cell (finding I1)."""

    def test_copies_the_blinded_inputs_under_the_cells_artifacts(self):
        tmp = Path(tempfile.mkdtemp())
        blind = tmp / "src" / "cell-abcd1234"
        blind.mkdir(parents=True)
        (blind / "diff.patch").write_text("patch")
        (blind / "acs.md").write_text("AC1. a")
        (blind / "tests.txt").write_text("ok")
        artifacts = tmp / "artifacts"
        artifacts.mkdir()

        target = grade.archive_blind_inputs({"artifacts": str(artifacts)}, blind)
        self.assertTrue((target / "diff.patch").exists())
        self.assertEqual((target / "acs.md").read_text(), "AC1. a")
        # The archive is NOT where the grader ran.
        self.assertNotEqual(target, blind)

    def test_is_idempotent(self):
        tmp = Path(tempfile.mkdtemp())
        blind = tmp / "src" / "cell-abcd1234"
        blind.mkdir(parents=True)
        (blind / "diff.patch").write_text("patch")
        artifacts = tmp / "artifacts"
        artifacts.mkdir()
        grade.archive_blind_inputs({"artifacts": str(artifacts)}, blind)
        target = grade.archive_blind_inputs({"artifacts": str(artifacts)}, blind)
        self.assertTrue((target / "diff.patch").exists())


class TestPlanRegexWordBoundary(unittest.TestCase):
    """CHANGE 4: the *plan*.md strip regex false-positives on real filenames.

    `explanation.md` is a real Diataxis filename in this repo, so stripping it
    silently deletes deliverable content from the graded diff.
    """

    def _diff(self, path):
        return (
            "diff --git a/{0} b/{0}\n"
            "index 111..222 100644\n"
            "--- a/{0}\n"
            "+++ b/{0}\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+new\n"
        ).format(path)

    def _stripped(self, path):
        return path not in grade.filter_diff(self._diff(path))

    def test_explanation_md_is_not_stripped(self):
        self.assertFalse(self._stripped("docs/concepts/explanation.md"))

    def test_planner_md_is_not_stripped(self):
        self.assertFalse(self._stripped("src/planner.md"))

    def test_planet_md_is_not_stripped(self):
        self.assertFalse(self._stripped("docs/planet.md"))

    def test_bare_plan_md_is_still_stripped(self):
        self.assertTrue(self._stripped("plan.md"))

    def test_hyphenated_plan_doc_is_still_stripped(self):
        self.assertTrue(self._stripped("docs/2026-01-01-thing-plan.md"))

    def test_underscored_plan_doc_is_still_stripped(self):
        self.assertTrue(self._stripped("notes/my_plan.md"))

    def test_suffixed_plan_doc_is_still_stripped(self):
        self.assertTrue(self._stripped("plan-2.md"))

    def test_plans_plural_is_still_stripped(self):
        self.assertTrue(self._stripped("plans.md"))


class TestFilteredDiffStatus(unittest.TestCase):
    """CHANGE 4: a non-empty raw diff that filters down to nothing must fail
    loudly, not be graded as an empty patch.

    measure.py computes empty_diff from the RAW numstat, so a cell whose
    deliverable lives entirely under a stripped path yields
    `empty_diff: false` and an empty `diff.patch`. The three graders then
    honestly report 0 findings and unmet ACs, and the report prints `OK`.
    """

    RAW = (
        "diff --git a/.claude/settings.json b/.claude/settings.json\n"
        "--- a/.claude/settings.json\n"
        "+++ b/.claude/settings.json\n"
        "@@ -1 +1 @@\n"
        "-old\n"
        "+new\n"
    )

    def test_raw_non_empty_but_filtered_empty_is_not_ok(self):
        status = grade.filtered_diff_status(self.RAW)
        self.assertFalse(status["ok"])
        self.assertTrue(status["filtered_diff_empty"])
        self.assertFalse(status["raw_diff_empty"])

    def test_note_names_the_stripped_paths(self):
        status = grade.filtered_diff_status(self.RAW)
        self.assertIn(".claude/settings.json", status["note"])

    def test_a_real_code_change_is_ok(self):
        raw = (
            "diff --git a/src/app.ts b/src/app.ts\n"
            "--- a/src/app.ts\n"
            "+++ b/src/app.ts\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+new\n"
        )
        status = grade.filtered_diff_status(raw)
        self.assertTrue(status["ok"])
        self.assertFalse(status["filtered_diff_empty"])

    def test_empty_raw_diff_is_measures_problem_not_ours(self):
        """An empty RAW diff is already caught by measure.py as empty_diff.
        This check is only for the case measure cannot see."""
        status = grade.filtered_diff_status("")
        self.assertTrue(status["raw_diff_empty"])
        self.assertTrue(status["ok"])

    def test_whitespace_only_filtered_output_counts_as_empty(self):
        raw = (
            "diff --git a/docs/adr/0001-x.md b/docs/adr/0001-x.md\n"
            "--- a/docs/adr/0001-x.md\n"
            "+++ b/docs/adr/0001-x.md\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+new\n"
        )
        self.assertFalse(grade.filtered_diff_status(raw)["ok"])
