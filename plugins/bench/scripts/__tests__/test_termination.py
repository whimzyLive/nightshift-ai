"""CHANGE 3: abnormal termination must fail the cell loudly.

On a subscription a story-sized session can be cut off mid-run by a rate
limit. The truncated transcript still reports a cost and still reconciles
(reconstructed and reported are both derived from the same truncated data),
so the harness would record a completed cell with suspiciously low spend and
a half-finished diff, and the report would show it as clean. That is exactly
the class of confidently-wrong number this harness exists to prevent.

The check is an ALLOW-LIST, not string matching against limit messages:
there is no rate-limit sample available on this machine to pattern-match
against, so anything that is not the known-good shape is a failure.
"""
import json
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import termination  # noqa: E402

# The shape a normal completion takes on this machine, established by direct
# inspection of real `claude -p --output-format json` output.
CLEAN_PAYLOAD = {
    "is_error": False,
    "subtype": "success",
    "stop_reason": "end_turn",
    "terminal_reason": "completed",
    "api_error_status": None,
    "num_turns": 42,
}


class TestCheckResultPayload(unittest.TestCase):
    def test_known_good_payload_is_clean(self):
        check = termination.check_result_payload(CLEAN_PAYLOAD)
        self.assertTrue(check["clean"])
        self.assertEqual(check["violations"], [])

    def test_is_error_true_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD, is_error=True)
        check = termination.check_result_payload(payload)
        self.assertFalse(check["clean"])
        self.assertTrue(any("is_error" in v for v in check["violations"]))

    def test_non_success_subtype_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD, subtype="error_max_turns")
        check = termination.check_result_payload(payload)
        self.assertFalse(check["clean"])
        self.assertTrue(any("error_max_turns" in v for v in check["violations"]))

    def test_novel_never_before_seen_subtype_is_not_clean(self):
        """The point of an allow-list: a value nobody has ever sampled still
        fails, because it is not the known-good shape. No string matching
        against limit messages is involved."""
        payload = dict(CLEAN_PAYLOAD, subtype="error_during_execution_novel")
        self.assertFalse(termination.check_result_payload(payload)["clean"])

    def test_missing_subtype_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD)
        del payload["subtype"]
        self.assertFalse(termination.check_result_payload(payload)["clean"])

    def test_non_none_api_error_status_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD, api_error_status=429)
        check = termination.check_result_payload(payload)
        self.assertFalse(check["clean"])
        self.assertTrue(any("429" in v for v in check["violations"]))

    def test_unexpected_stop_reason_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD, stop_reason="max_tokens")
        check = termination.check_result_payload(payload)
        self.assertFalse(check["clean"])
        self.assertTrue(any("max_tokens" in v for v in check["violations"]))

    def test_absent_stop_reason_is_not_a_violation(self):
        """Absent is "not observed", not "unexpected value" -- an older CLI
        that never emitted the field must not fail every cell."""
        payload = dict(CLEAN_PAYLOAD)
        del payload["stop_reason"]
        self.assertTrue(termination.check_result_payload(payload)["clean"])

    def test_absent_terminal_reason_is_not_a_violation(self):
        payload = dict(CLEAN_PAYLOAD)
        del payload["terminal_reason"]
        self.assertTrue(termination.check_result_payload(payload)["clean"])

    def test_unexpected_terminal_reason_is_not_clean(self):
        payload = dict(CLEAN_PAYLOAD, terminal_reason="interrupted")
        check = termination.check_result_payload(payload)
        self.assertFalse(check["clean"])
        self.assertTrue(any("interrupted" in v for v in check["violations"]))

    def test_observed_values_are_recorded_verbatim(self):
        payload = dict(
            CLEAN_PAYLOAD, subtype="weird", api_error_status=529, num_turns=3
        )
        observed = termination.check_result_payload(payload)["observed"]
        self.assertEqual(observed["subtype"], "weird")
        self.assertEqual(observed["api_error_status"], 529)
        self.assertEqual(observed["num_turns"], 3)
        self.assertEqual(observed["stop_reason"], "end_turn")

    def test_tool_use_stop_reason_is_not_accepted_on_the_result_payload(self):
        """`tool_use` is a real value on intermediate assistant entries, but a
        RESULT payload that stopped wanting to call a tool did not finish."""
        payload = dict(CLEAN_PAYLOAD, stop_reason="tool_use")
        self.assertFalse(termination.check_result_payload(payload)["clean"])


def _write_transcript(path, entries):
    path.write_text("\n".join(json.dumps(e) for e in entries) + "\n")
    return path


class TestScanTranscript(unittest.TestCase):
    def test_api_error_with_null_rate_limits_is_not_a_violation(self):
        """The two real samples on this machine are connection errors whose
        rateLimits field is null. Those are not rate limits."""
        with TemporaryDirectory() as tmp:
            path = _write_transcript(
                Path(tmp) / "t.jsonl",
                [
                    {
                        "type": "system",
                        "subtype": "api_error",
                        "error": {"message": "ECONNRESET", "rateLimits": None},
                    }
                ],
            )
            self.assertEqual(termination.scan_transcript(path), [])

    def test_api_error_with_rate_limits_payload_is_a_violation(self):
        limits = {"unified_5h": {"status": "exhausted", "resetsAt": 1234567890}}
        with TemporaryDirectory() as tmp:
            path = _write_transcript(
                Path(tmp) / "t.jsonl",
                [
                    {"type": "assistant", "message": {"content": "hi"}},
                    {
                        "type": "system",
                        "subtype": "api_error",
                        "timestamp": "2026-07-28T00:00:00Z",
                        "error": {
                            "status": 429,
                            "formatted": "429 rate limit",
                            "rateLimits": limits,
                        },
                    },
                ],
            )
            found = termination.scan_transcript(path)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["rateLimits"], limits)
        self.assertEqual(found[0]["status"], 429)

    def test_ordinary_transcript_yields_nothing(self):
        with TemporaryDirectory() as tmp:
            path = _write_transcript(
                Path(tmp) / "t.jsonl",
                [{"type": "assistant", "message": {"content": "hi"}}],
            )
            self.assertEqual(termination.scan_transcript(path), [])

    def test_malformed_line_does_not_abort_the_scan(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.jsonl"
            path.write_text(
                "{not json\n"
                + json.dumps(
                    {
                        "type": "system",
                        "subtype": "api_error",
                        "error": {"rateLimits": {"a": 1}},
                    }
                )
                + "\n"
            )
            self.assertEqual(len(termination.scan_transcript(path)), 1)


class TestCombine(unittest.TestCase):
    def test_clean_result_and_clean_transcript_is_clean(self):
        combined = termination.combine(
            termination.check_result_payload(CLEAN_PAYLOAD), []
        )
        self.assertTrue(combined["clean"])
        self.assertEqual(combined["note"], "")

    def test_rate_limit_entry_alone_fails_the_cell(self):
        """The result payload can look perfectly normal and the transcript
        still show the session was throttled."""
        entries = [{"rateLimits": {"unified_5h": "exhausted"}, "status": 429}]
        combined = termination.combine(
            termination.check_result_payload(CLEAN_PAYLOAD), entries
        )
        self.assertFalse(combined["clean"])
        self.assertEqual(combined["rate_limit_entries"], entries)
        self.assertTrue(combined["violations"])

    def test_note_says_the_cell_is_failed_and_must_be_re_run_by_hand(self):
        combined = termination.combine(
            termination.check_result_payload(dict(CLEAN_PAYLOAD, is_error=True)), []
        )
        self.assertIn("FAILED", combined["note"])
        note = combined["note"].lower()
        self.assertIn("re-run", note)

    def test_no_auto_resume_or_retry_logic_exists(self):
        """The founder's ruling: fail loudly, no auto-resume, no sleeping and
        retrying. Assert the module contains no waiting logic."""
        source = Path(termination.__file__).read_text()
        self.assertNotIn("time.sleep", source)
        self.assertNotIn("import time", source)

    def test_observed_values_survive_into_the_combined_record(self):
        combined = termination.combine(
            termination.check_result_payload(dict(CLEAN_PAYLOAD, subtype="nope")), []
        )
        self.assertEqual(combined["observed"]["subtype"], "nope")
        self.assertEqual(combined["observed"]["num_turns"], 42)


if __name__ == "__main__":
    unittest.main()
