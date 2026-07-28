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


if __name__ == "__main__":
    unittest.main()
