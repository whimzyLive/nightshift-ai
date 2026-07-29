import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import provision  # noqa: E402


class TestBranchName(unittest.TestCase):
    def test_always_prefixed_with_bench(self):
        name = provision.branch_name("NA-68", "opus", "r1")
        self.assertTrue(name.startswith("bench/"))
        self.assertEqual(name, "bench/NA-68/opus/r1")


class TestAssertBenchBranch(unittest.TestCase):
    def test_accepts_bench_branch(self):
        provision.assert_bench_branch("bench/NA-68/opus/r1")

    def test_rejects_develop(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("develop")

    def test_rejects_main(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("main")

    def test_rejects_lookalike_prefix(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("benchmarks/NA-68")

    def test_rejects_traversal(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/../develop")

    # Cases that are currently wrongly accepted (regression tests after fix)
    def test_rejects_refspec_colon(self):
        """Refspec src:dst syntax should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x:refs/heads/main")

    def test_rejects_trailing_newline(self):
        """Trailing newline should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x\n")

    def test_rejects_embedded_newline(self):
        """Embedded newline smuggling second ref should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x\ndevelop")

    def test_rejects_trailing_space(self):
        """Trailing space should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x ")

    def test_rejects_leading_space(self):
        """Leading space should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch(" bench/x")

    def test_rejects_consecutive_slashes(self):
        """Consecutive slashes should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench//x")

    def test_rejects_dot_slash_segment(self):
        """Dot-slash segment should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/./x")

    def test_rejects_dotdot_slash_segment(self):
        """Dot-dot-slash segment should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench//../x")

    def test_rejects_trailing_dot_lock(self):
        """Trailing .lock should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x.lock")

    def test_rejects_leading_slash(self):
        """Leading slash should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("/bench/x")

    def test_rejects_tilde(self):
        """Tilde should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/~x")

    def test_rejects_caret(self):
        """Caret should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/^x")

    def test_rejects_question_mark(self):
        """Question mark should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/?x")

    def test_rejects_asterisk(self):
        """Asterisk should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/*x")

    def test_rejects_bracket(self):
        """Bracket should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/[x]")

    def test_rejects_backslash(self):
        """Backslash should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x\\y")

    def test_rejects_tab(self):
        """Tab character should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x\ty")

    def test_rejects_carriage_return(self):
        """Carriage return should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x\ry")

    def test_rejects_zero_width_space(self):
        """Zero-width space should be rejected (non-ASCII)."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/​x")

    def test_rejects_accented_lookalike(self):
        """Accented lookalike (non-ASCII) should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/ö")

    def test_rejects_unicode_fraction_slash(self):
        """Unicode fraction slash (non-ASCII) should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x⁄y")

    def test_rejects_empty_string(self):
        """Empty string should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("")

    def test_rejects_bench_only(self):
        """Just 'bench' without slash should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench")

    def test_rejects_bench_with_traversal_escape(self):
        """Complex traversal escape should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/x/../../develop")

    def test_rejects_refs_heads_prefix(self):
        """refs/heads/ prefix should be rejected."""
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("refs/heads/develop")

    def test_accepts_legitimate_bench_name(self):
        """Legitimate branch names from branch_name() should pass."""
        name = provision.branch_name("NA-100", "sonnet", "run-5")
        provision.assert_bench_branch(name)


if __name__ == "__main__":
    unittest.main()


class TestBenchSettingsLocal(unittest.TestCase):
    """The measured session must be able to commit and run tests (finding C4)."""

    def _worktree(self):
        return Path(tempfile.mkdtemp())

    def test_writes_settings_local_json_into_the_worktree(self):
        wt = self._worktree()
        path = provision.write_bench_settings(wt)
        self.assertTrue(path.exists())
        self.assertEqual(path, wt / ".claude" / "settings.local.json")

    def test_grants_bash_for_git_commit(self):
        wt = self._worktree()
        data = json.loads(provision.write_bench_settings(wt).read_text())
        allow = data["permissions"]["allow"]
        self.assertIn("Bash(git commit:*)", allow)
        self.assertIn("Bash(git add:*)", allow)

    def test_grants_bash_for_the_test_runner(self):
        wt = self._worktree()
        data = json.loads(provision.write_bench_settings(wt).read_text())
        allow = data["permissions"]["allow"]
        self.assertIn("Bash(pnpm:*)", allow)
        self.assertIn("Bash(npm:*)", allow)

    def test_never_grants_push_or_merge(self):
        wt = self._worktree()
        data = json.loads(provision.write_bench_settings(wt).read_text())
        allow = data["permissions"]["allow"]
        deny = data["permissions"]["deny"]
        # The base allow list still grants none of these. `git push` is no
        # longer blanket-denied -- it moved to the PreToolUse guard, which
        # permits only this cell's own refs -- but nothing grants it here
        # either, so the guard is the only thing that can let one through.
        for forbidden in ("push", "merge", "rebase"):
            self.assertFalse(
                any(forbidden in entry for entry in allow),
                "allow list must never permit {0}: {1}".format(forbidden, allow),
            )
        # Force-push and history rewriting stay blunt denies: deny resolves
        # before any hook, so these hold even if the guard fails to load.
        self.assertIn("Bash(git push --force:*)", deny)
        self.assertIn("Bash(git merge:*)", deny)
        self.assertIn("Bash(git rebase:*)", deny)
        self.assertIn("Bash(gh pr merge:*)", deny)
        self.assertIn("Bash(gh pr ready:*)", deny)

    def test_carries_a_comment_explaining_why_it_exists(self):
        wt = self._worktree()
        data = json.loads(provision.write_bench_settings(wt).read_text())
        comment = data["_comment"]
        self.assertIn("acceptEdits", comment)
        self.assertIn("harness friction", comment)

    def test_is_valid_json(self):
        wt = self._worktree()
        json.loads(provision.write_bench_settings(wt).read_text())
