import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import measure  # noqa: E402

# PRICING mirrors pricing.json's per-model rate shape (cache_write split by
# TTL bucket -- see Finding 1 of the fix-round-1 review). cache_write_1h is
# what price_entry falls back to when usage carries only the flat
# "cache_creation_input_tokens" bucket (no TTL split), which is what the
# original brief's test fixtures below exercise -- so cache_write_1h=6.25
# preserves the pre-fix-round expected totals unchanged.
PRICING = {
    "claude-opus-5": {
        "input": 5.0,
        "output": 25.0,
        "cache_write_1h": 6.25,
        "cache_write_5m": 3.0,
        "cache_read": 0.5,
    }
}


class TestPriceEntry(unittest.TestCase):
    def test_prices_all_four_token_classes(self):
        usage = {
            "input_tokens": 1_000_000,
            "output_tokens": 1_000_000,
            "cache_creation_input_tokens": 1_000_000,
            "cache_read_input_tokens": 1_000_000,
        }
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5", PRICING), 36.75, places=4
        )

    def test_strips_context_window_suffix_from_model_id(self):
        usage = {"input_tokens": 1_000_000}
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5[1m]", PRICING), 5.0, places=4
        )

    def test_unknown_model_raises(self):
        with self.assertRaises(KeyError):
            measure.price_entry({"input_tokens": 1}, "not-a-model", PRICING)

    def test_falls_back_to_flat_bucket_at_1h_rate_when_no_ttl_split(self):
        # No "cache_creation" sub-object -- only the legacy flat field.
        usage = {"cache_creation_input_tokens": 1_000_000}
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5", PRICING), 6.25, places=4
        )

    def test_prices_1h_and_5m_cache_buckets_separately(self):
        usage = {
            "cache_creation": {
                "ephemeral_1h_input_tokens": 1_000_000,
                "ephemeral_5m_input_tokens": 1_000_000,
            }
        }
        # 1_000_000 * 6.25 (1h) + 1_000_000 * 3.0 (5m), per million
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5", PRICING), 9.25, places=4
        )

    def test_ttl_split_present_but_empty_prices_as_zero_not_fallback(self):
        # A present-but-zeroed cache_creation object must NOT fall back to
        # pricing a flat "cache_creation_input_tokens" bucket that happens
        # to also be present -- the split data, even if all-zero, is
        # authoritative once present.
        usage = {
            "cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0},
            "cache_creation_input_tokens": 1_000_000,
        }
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5", PRICING), 0.0, places=4
        )


class TestAssignPhases(unittest.TestCase):
    def _phase(self, pid, marker):
        return {"id": pid, "marker": marker}

    def test_single_phase_when_no_markers(self):
        entries = [{"type": "assistant", "text": "x"}, {"type": "assistant", "text": "y"}]
        tagged = measure.assign_phases(entries, [self._phase("impl", "")])
        self.assertEqual([e["phase"] for e in tagged], ["impl", "impl"])

    def test_switches_phase_on_marker(self):
        entries = [
            {"type": "user", "text": "/sdlc:impl go"},
            {"type": "assistant", "text": "working"},
            {"type": "user", "text": "/sdlc:review now"},
            {"type": "assistant", "text": "reviewing"},
        ]
        phases = [self._phase("impl", "/sdlc:impl"), self._phase("review-fix", "/sdlc:review")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual([e["phase"] for e in tagged], ["impl", "impl", "review-fix", "review-fix"])

    def test_entries_before_any_marker_go_to_first_phase(self):
        entries = [{"type": "assistant", "text": "preamble"}]
        phases = [self._phase("impl", "/sdlc:impl"), self._phase("review-fix", "/sdlc:review")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual(tagged[0]["phase"], "impl")

    def test_regex_alternation_in_marker(self):
        entries = [{"type": "user", "text": "/sdlc:review-fix"}]
        phases = [self._phase("impl", ""), self._phase("rf", "/sdlc:review|/sdlc:review-fix")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual(tagged[0]["phase"], "rf")

    def test_invalid_marker_regex_raises_value_error_naming_phase_and_pattern(self):
        entries = [{"type": "assistant", "text": "x"}]
        phases = [self._phase("impl", "(unbalanced")]
        with self.assertRaises(ValueError) as ctx:
            measure.assign_phases(entries, phases)
        message = str(ctx.exception)
        self.assertIn("impl", message)
        self.assertIn("(unbalanced", message)


class TestInstructionFloor(unittest.TestCase):
    def test_floor_is_the_minimum_resident_context(self):
        self.assertEqual(measure.instruction_floor([15000, 22000, 31000]), 15000)

    def test_empty_returns_zero(self):
        self.assertEqual(measure.instruction_floor([]), 0)


class TestReconcile(unittest.TestCase):
    def test_within_tolerance_passes(self):
        self.assertTrue(measure.reconcile(100.0, 101.0))

    def test_outside_tolerance_fails(self):
        self.assertFalse(measure.reconcile(100.0, 110.0))

    def test_zero_reported_is_not_a_division_error(self):
        self.assertFalse(measure.reconcile(1.0, 0.0))


class TestFindTranscript(unittest.TestCase):
    def test_returns_none_when_no_match(self):
        with TemporaryDirectory() as tmp:
            with patch.object(measure, "PROJECTS_DIR", Path(tmp)):
                self.assertIsNone(measure.find_transcript("sess-missing"))

    def test_returns_single_match(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = root / "-Users-me-project"
            project.mkdir()
            transcript = project / "sess-1.jsonl"
            transcript.write_text("")
            with patch.object(measure, "PROJECTS_DIR", root):
                self.assertEqual(measure.find_transcript("sess-1"), transcript)

    def test_raises_naming_all_candidates_on_multiple_matches(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            project_a = root / "-Users-me-project-a"
            project_b = root / "-Users-me-project-b"
            project_a.mkdir()
            project_b.mkdir()
            transcript_a = project_a / "sess-dup.jsonl"
            transcript_b = project_b / "sess-dup.jsonl"
            transcript_a.write_text("")
            transcript_b.write_text("")
            with patch.object(measure, "PROJECTS_DIR", root):
                with self.assertRaises(RuntimeError) as ctx:
                    measure.find_transcript("sess-dup")
                message = str(ctx.exception)
                self.assertIn(str(transcript_a), message)
                self.assertIn(str(transcript_b), message)


def _write_transcript(path, lines):
    path.write_text("\n".join(json.dumps(line) for line in lines))


class TestCountToolUses(unittest.TestCase):
    def test_counts_only_requested_tool_names(self):
        with TemporaryDirectory() as tmp:
            transcript = Path(tmp) / "sess.jsonl"
            _write_transcript(
                transcript,
                [
                    {
                        "type": "assistant",
                        "message": {
                            "content": [
                                {"type": "text", "text": "working"},
                                {"type": "tool_use", "name": "Edit", "input": {}},
                            ]
                        },
                    },
                    {
                        "type": "assistant",
                        "message": {
                            "content": [
                                {"type": "tool_use", "name": "Write", "input": {}},
                                {"type": "tool_use", "name": "Bash", "input": {}},
                            ]
                        },
                    },
                    {
                        "type": "assistant",
                        "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {}}]},
                    },
                ],
            )
            counts = measure.count_tool_uses(transcript, ["Edit", "Write"])
            self.assertEqual(counts, {"Edit": 2, "Write": 1})

    def test_zero_counts_when_no_matching_tool_use(self):
        with TemporaryDirectory() as tmp:
            transcript = Path(tmp) / "sess.jsonl"
            _write_transcript(
                transcript,
                [{"type": "assistant", "message": {"content": [{"type": "text", "text": "hi"}]}}],
            )
            counts = measure.count_tool_uses(transcript, ["Edit", "Write"])
            self.assertEqual(counts, {"Edit": 0, "Write": 0})


def _git(cwd, *args):
    env_args = [
        "git",
        "-c", "user.name=Bench Test",
        "-c", "user.email=bench-test@example.com",
        "-C", str(cwd),
        *args,
    ]
    subprocess.run(env_args, check=True, capture_output=True, text=True)


class TestGitNumstat(unittest.TestCase):
    """Exercises git_numstat against a disposable repo created in a temp
    directory. Never touches this repository."""

    def test_counts_files_and_lines_between_two_commits(self):
        with TemporaryDirectory() as tmp:
            repo = Path(tmp) / "throwaway-repo"
            repo.mkdir()
            _git(repo, "init", "-q")

            (repo / "a.txt").write_text("line1\nline2\n")
            _git(repo, "add", "a.txt")
            _git(repo, "commit", "-q", "-m", "initial")
            base_sha = subprocess.run(
                ["git", "-C", str(repo), "rev-parse", "HEAD"],
                check=True, capture_output=True, text=True,
            ).stdout.strip()

            (repo / "a.txt").write_text("line1\nline2\nline3\n")
            (repo / "b.txt").write_text("new file\n")
            _git(repo, "add", "-A")
            _git(repo, "commit", "-q", "-m", "second")

            stats = measure.git_numstat(str(repo), base_sha)
            self.assertEqual(stats["files_touched"], 2)
            self.assertEqual(stats["lines_added"], 2)  # +line3 in a.txt, +1 line in b.txt
            self.assertEqual(stats["lines_removed"], 0)

    def test_no_diff_when_base_equals_head(self):
        with TemporaryDirectory() as tmp:
            repo = Path(tmp) / "throwaway-repo"
            repo.mkdir()
            _git(repo, "init", "-q")
            (repo / "a.txt").write_text("line1\n")
            _git(repo, "add", "a.txt")
            _git(repo, "commit", "-q", "-m", "initial")
            head_sha = subprocess.run(
                ["git", "-C", str(repo), "rev-parse", "HEAD"],
                check=True, capture_output=True, text=True,
            ).stdout.strip()

            stats = measure.git_numstat(str(repo), head_sha)
            self.assertEqual(stats, {"files_touched": 0, "lines_added": 0, "lines_removed": 0})


class TestSummarise(unittest.TestCase):
    def test_sidechain_entries_are_priced_into_their_phase_bucket_not_skipped(self):
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": "claude-opus-5",
                "is_sidechain": False,
                "usage": {"input_tokens": 100},
            },
            {
                "type": "assistant",
                "phase": "impl",
                "model": "claude-opus-5",
                "is_sidechain": True,  # a subagent turn
                "usage": {"input_tokens": 200},
            },
        ]
        summary = measure.summarise(entries, PRICING)
        bucket = summary["by_phase"]["impl"]
        # Both requests counted, including the sidechain one's cost.
        self.assertEqual(bucket["requests"], 2)
        self.assertEqual(bucket["subagent_requests"], 1)
        expected_cost = (100 * PRICING["claude-opus-5"]["input"] + 200 * PRICING["claude-opus-5"]["input"]) / 1_000_000
        self.assertAlmostEqual(bucket["cost_usd"], expected_cost, places=6)

    def test_non_assistant_entries_are_excluded(self):
        entries = [
            {"type": "user", "phase": "impl", "model": None, "is_sidechain": False, "usage": {}},
        ]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["by_phase"], {})

    def test_context_floor_uses_minimum_resident_tokens(self):
        entries = [
            {
                "type": "assistant", "phase": "impl", "model": "claude-opus-5",
                "is_sidechain": False, "usage": {"input_tokens": 15000},
            },
            {
                "type": "assistant", "phase": "impl", "model": "claude-opus-5",
                "is_sidechain": False, "usage": {"input_tokens": 31000},
            },
        ]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["context"]["instruction_floor_tokens"], 15000)
        self.assertEqual(summary["context"]["peak_resident_tokens"], 31000)


if __name__ == "__main__":
    unittest.main()
