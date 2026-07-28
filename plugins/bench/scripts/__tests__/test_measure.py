import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import measure  # noqa: E402

PRICING = {
    "claude-opus-5": {
        "input": 5.0,
        "output": 25.0,
        "cache_write": 6.25,
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


if __name__ == "__main__":
    unittest.main()
