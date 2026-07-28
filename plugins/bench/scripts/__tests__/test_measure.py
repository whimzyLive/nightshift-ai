import json
import os
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
    def test_every_assistant_entry_is_priced_into_its_phase_bucket(self):
        # NOTE: this test previously asserted that an `isSidechain: true`
        # entry incremented subagent_requests. That behaviour was dead code
        # -- real transcripts contain no isSidechain entries at all (finding
        # C1) -- so the assertion has moved to the toolUseResult path below.
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
                "is_sidechain": True,
                "usage": {"input_tokens": 200},
            },
        ]
        summary = measure.summarise(entries, PRICING)
        bucket = summary["by_phase"]["impl"]
        self.assertEqual(bucket["requests"], 2)
        expected_cost = (100 * PRICING["claude-opus-5"]["input"] + 200 * PRICING["claude-opus-5"]["input"]) / 1_000_000
        self.assertAlmostEqual(bucket["cost_usd"], expected_cost, places=6)

    def test_non_assistant_entries_without_tool_usage_are_excluded(self):
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


def _sub_entry(phase, model, usage, entry_type="user"):
    return {
        "type": entry_type,
        "phase": phase,
        "model": None,
        "is_sidechain": False,
        "usage": {},
        "subagent_usage": usage,
        "subagent_model": model,
        "subagent_id": "agent_1",
    }


class TestSubagentAccounting(unittest.TestCase):
    """Subagent spend lives in toolUseResult, not isSidechain (finding C1)."""

    def test_read_entries_captures_tool_use_result_usage(self):
        with TemporaryDirectory() as tmp:
            transcript = Path(tmp) / "s.jsonl"
            transcript.write_text(
                json.dumps(
                    {
                        "type": "user",
                        "toolUseResult": {
                            "usage": {"input_tokens": 500, "output_tokens": 20},
                            "resolvedModel": "claude-opus-5[1m]",
                            "agentId": "agent_abc",
                        },
                    }
                )
                + "\n"
            )
            entries = measure.read_entries(transcript)
        self.assertEqual(entries[0]["subagent_usage"]["input_tokens"], 500)
        self.assertEqual(entries[0]["subagent_model"], "claude-opus-5[1m]")
        self.assertEqual(entries[0]["subagent_id"], "agent_abc")

    def test_read_entries_tolerates_non_dict_tool_use_result(self):
        # toolUseResult is frequently a plain string (e.g. Bash output).
        with TemporaryDirectory() as tmp:
            transcript = Path(tmp) / "s.jsonl"
            transcript.write_text(
                json.dumps({"type": "user", "toolUseResult": "some stdout"}) + "\n"
            )
            entries = measure.read_entries(transcript)
        self.assertIsNone(entries[0]["subagent_usage"])

    def test_subagent_cost_is_counted_and_attributed_to_the_entrys_phase(self):
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": "claude-opus-5",
                "is_sidechain": False,
                "usage": {"input_tokens": 1_000_000},
            },
            _sub_entry("impl", "claude-opus-5", {"input_tokens": 200_000}),
        ]
        summary = measure.summarise(entries, PRICING)
        bucket = summary["by_phase"]["impl"]
        self.assertEqual(bucket["subagent_requests"], 1)
        self.assertAlmostEqual(bucket["subagent_cost_usd"], 1.0, places=6)
        # Phase cost is main + subagent, so the total reconciles.
        self.assertAlmostEqual(bucket["cost_usd"], 6.0, places=6)
        self.assertEqual(summary["subagents"]["requests"], 1)
        self.assertAlmostEqual(summary["subagents"]["cost_usd"], 1.0, places=6)

    def test_subagent_requests_is_no_longer_always_zero(self):
        entries = [_sub_entry("impl", "claude-opus-5", {"output_tokens": 1000})]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["by_phase"]["impl"]["subagent_requests"], 1)
        self.assertGreater(summary["by_phase"]["impl"]["cost_usd"], 0.0)

    def test_subagent_tokens_do_not_pollute_the_context_floor(self):
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": "claude-opus-5",
                "is_sidechain": False,
                "usage": {"input_tokens": 15000},
            },
            _sub_entry("impl", "claude-opus-5", {"input_tokens": 400}),
        ]
        summary = measure.summarise(entries, PRICING)
        # 400 is not the instruction floor -- that subagent context is not
        # the measured session's context.
        self.assertEqual(summary["context"]["instruction_floor_tokens"], 15000)
        self.assertEqual(summary["by_phase"]["impl"]["subagent_tokens"], 400)

    def test_subagent_models_are_recorded(self):
        entries = [_sub_entry("impl", "claude-opus-5[1m]", {"input_tokens": 10})]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["subagents"]["models"], {"claude-opus-5": 1})


class TestUnpriceableModels(unittest.TestCase):
    """An unknown model id must never destroy a paid run (finding C2)."""

    def test_price_entry_raises_a_named_error_not_a_bare_keyerror(self):
        with self.assertRaises(measure.UnpriceableModelError):
            measure.price_entry({"input_tokens": 1}, "claude-sonnet-4-6", PRICING)

    def test_summarise_does_not_raise_on_an_unknown_model(self):
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": "claude-sonnet-4-6",
                "is_sidechain": False,
                "usage": {"input_tokens": 1_000_000},
            }
        ]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["unpriceable_models"], {"claude-sonnet-4-6": 1})
        self.assertEqual(summary["by_phase"]["impl"]["cost_usd"], 0.0)

    def test_none_model_is_recorded_not_crashed_on(self):
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": None,
                "is_sidechain": False,
                "usage": {"output_tokens": 5},
            }
        ]
        summary = measure.summarise(entries, PRICING)
        self.assertIn("<missing model id>", summary["unpriceable_models"])

    def test_zero_usage_unknown_model_is_not_flagged(self):
        # `<synthetic>` always carries all-zero usage -- zero tokens cost zero
        # under any rate card, so there is nothing to flag.
        entries = [
            {
                "type": "assistant",
                "phase": "impl",
                "model": "<synthetic>",
                "is_sidechain": False,
                "usage": {
                    "input_tokens": 0,
                    "output_tokens": 0,
                    "cache_creation_input_tokens": 0,
                    "cache_read_input_tokens": 0,
                },
            }
        ]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["unpriceable_models"], {})

    def test_unpriceable_subagent_model_is_recorded_too(self):
        entries = [_sub_entry("impl", "some-future-model", {"input_tokens": 10})]
        summary = measure.summarise(entries, PRICING)
        self.assertEqual(summary["unpriceable_models"], {"some-future-model": 1})

    def test_shipped_pricing_json_prices_every_observed_model_id(self):
        pricing = measure.load_pricing()
        # Every model id observed across all 2204 transcripts on this
        # machine, plus the [1m] suffixed forms seen on subagent results.
        for model in (
            "claude-opus-5",
            "claude-opus-5[1m]",
            "claude-opus-4-8",
            "claude-opus-4-8[1m]",
            "claude-fable-5",
            "claude-sonnet-5",
            "claude-sonnet-4-6",
            "claude-haiku-4-5",
            "claude-haiku-4-5-20251001",
        ):
            measure.price_entry({"input_tokens": 1}, model, pricing)


class TestPhaseMarkerFires(unittest.TestCase):
    """The split is only meaningful if a marker actually fired (finding C3)."""

    def _entries(self, *texts):
        return [{"type": "assistant", "text": t} for t in texts]

    def test_counts_each_phases_marker_fires(self):
        phases = [
            {"id": "spec", "marker": r"/sdlc:spec"},
            {"id": "impl", "marker": r"/sdlc:impl"},
        ]
        result = measure.assign_phases_with_fires(
            self._entries("run /sdlc:spec", "now /sdlc:impl", "more /sdlc:impl"),
            phases,
        )
        self.assertEqual(result.marker_fires, {"spec": 1, "impl": 2})

    def test_reports_zero_fires_when_no_marker_matches(self):
        phases = [
            {"id": "spec", "marker": r"/sdlc:spec"},
            {"id": "impl", "marker": r"/sdlc:impl"},
        ]
        result = measure.assign_phases_with_fires(
            self._entries("just doing the work inline"), phases
        )
        self.assertEqual(result.marker_fires, {"spec": 0, "impl": 0})
        # ...and everything defaulted into the first declared phase.
        self.assertEqual(result.entries[0]["phase"], "spec")

    def test_attribution_unavailable_when_many_phases_and_no_fire(self):
        phases = [
            {"id": "spec", "marker": r"/sdlc:spec"},
            {"id": "impl", "marker": r"/sdlc:impl"},
            {"id": "review-fix", "marker": r"/sdlc:review"},
        ]
        attribution = measure.phase_attribution(
            phases, {"spec": 0, "impl": 0, "review-fix": 0}
        )
        self.assertFalse(attribution["available"])
        self.assertFalse(attribution["any_marker_fired"])
        self.assertIn("no phase marker matched", attribution["note"])

    def test_attribution_available_for_a_single_markerless_phase(self):
        # opus.yaml: one declared phase, empty marker. Nothing to attribute.
        attribution = measure.phase_attribution([{"id": "impl", "marker": ""}], {"impl": 0})
        self.assertTrue(attribution["available"])
        self.assertEqual(attribution["note"], "")

    def test_attribution_available_once_any_marker_fires(self):
        phases = [{"id": "spec", "marker": "a"}, {"id": "impl", "marker": "b"}]
        attribution = measure.phase_attribution(phases, {"spec": 0, "impl": 3})
        self.assertTrue(attribution["available"])

    def test_assign_phases_still_returns_a_plain_list(self):
        tagged = measure.assign_phases(self._entries("x"), [{"id": "impl", "marker": ""}])
        self.assertIsInstance(tagged, list)
        self.assertEqual(tagged[0]["phase"], "impl")


if __name__ == "__main__":
    unittest.main()


def _throwaway_repo(tmp):
    """A disposable git repo. Never run git fixtures against the real repo."""
    repo = Path(tmp) / "repo"
    repo.mkdir()
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    def run(*args):
        subprocess.run(["git", "-C", str(repo)] + list(args), check=True,
                       capture_output=True, env={**os.environ, **env})
    run("init", "-q", "-b", "main")
    (repo / "a.txt").write_text("base\n")
    run("add", "-A")
    run("commit", "-qm", "base")
    base = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()
    return repo, base, run


class TestEmptyDiffGuard(unittest.TestCase):
    """A cell that produced no code change is a failed cell (finding C4)."""

    def _transcript(self, tmp, edits=0):
        path = Path(tmp) / "t.jsonl"
        lines = []
        for _ in range(edits):
            lines.append(json.dumps({
                "type": "assistant",
                "message": {"content": [{"type": "tool_use", "name": "Edit"}]},
            }))
        path.write_text("\n".join(lines) + ("\n" if lines else ""))
        return path

    def test_empty_diff_is_flagged(self):
        with TemporaryDirectory() as tmp:
            repo, base, _ = _throwaway_repo(tmp)
            transcript = self._transcript(tmp, edits=3)
            work = measure.compute_work_done(
                {"worktree": str(repo), "base_sha": base}, transcript
            )
        self.assertTrue(work["empty_diff"])
        self.assertEqual(work["files_touched"], 0)
        self.assertIn("no code change", work["empty_diff_note"])

    def test_note_names_the_edit_calls_so_the_cause_is_diagnosable(self):
        with TemporaryDirectory() as tmp:
            repo, base, _ = _throwaway_repo(tmp)
            transcript = self._transcript(tmp, edits=7)
            work = measure.compute_work_done(
                {"worktree": str(repo), "base_sha": base}, transcript
            )
        # 7 edits but an empty diff => work was done but never committed.
        self.assertEqual(work["edit_calls"], 7)
        self.assertIn("7 Edit", work["empty_diff_note"])
        self.assertIn("settings.local.json", work["empty_diff_note"])

    def test_a_real_commit_is_not_flagged(self):
        with TemporaryDirectory() as tmp:
            repo, base, run = _throwaway_repo(tmp)
            (repo / "a.txt").write_text("base\nchanged\n")
            run("add", "-A")
            run("commit", "-qm", "work")
            transcript = self._transcript(tmp, edits=1)
            work = measure.compute_work_done(
                {"worktree": str(repo), "base_sha": base}, transcript
            )
        self.assertFalse(work["empty_diff"])
        self.assertEqual(work["empty_diff_note"], "")
        self.assertEqual(work["files_touched"], 1)


class TestBillingModeCarryThrough(unittest.TestCase):
    """CHANGE 1: the billing mode recorded at execute time must reach run.json.

    report.py reads it from there. A reader months later must be able to tell
    which basis a row's dollar figures were measured on without re-deriving
    it from the machine they happen to be standing at.
    """

    def test_billing_mode_is_carried_from_result(self):
        result = {
            "billing_mode": {
                "mode": "subscription",
                "api_key_env_var": None,
                "settings_evidence": [],
                "evidence": "no API key present; billed against the operator's subscription",
            }
        }
        carried = measure.billing_mode_from_result(result)
        self.assertEqual(carried["mode"], "subscription")
        self.assertIn("subscription", carried["evidence"])

    def test_result_without_billing_mode_is_unknown_not_assumed(self):
        """A result.json written before this field existed must not be
        silently relabelled as a subscription run."""
        carried = measure.billing_mode_from_result({})
        self.assertEqual(carried["mode"], "unknown")
        self.assertTrue(carried["evidence"])
