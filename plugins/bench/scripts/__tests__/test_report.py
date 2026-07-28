import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import report  # noqa: E402

RUN = {
    "approach": "sdlc",
    "total": {"reported_cost_usd": 46.67, "duration_ms": 600000},
    "by_phase": {
        "spec": {"cost_usd": 3.0},
        "plan": {"cost_usd": 2.0},
        "impl": {"cost_usd": 30.0},
        "review-fix": {"cost_usd": 8.0},
        "docs": {"cost_usd": 3.67},
    },
    "reconciliation": {"ok": True},
    "grades": {"acs": {"AC1": {"met": True}}, "findings_count": 2},
}


class TestPhaseRows(unittest.TestCase):
    def test_splits_impl_review_and_ceremony(self):
        row = report.phase_rows([RUN])[0]
        self.assertAlmostEqual(row["impl"], 30.0)
        self.assertAlmostEqual(row["review_fix"], 8.0)
        self.assertAlmostEqual(row["ceremony"], 8.67)

    def test_approach_without_ceremony_reports_zero(self):
        run = {
            "approach": "opus",
            "total": {"reported_cost_usd": 9.71, "duration_ms": 1},
            "by_phase": {"impl": {"cost_usd": 9.71}},
            "reconciliation": {"ok": True},
            "grades": {"acs": {}, "findings_count": 0},
        }
        row = report.phase_rows([run])[0]
        self.assertEqual(row["ceremony"], 0.0)
        self.assertEqual(row["review_fix"], 0.0)


class TestRenderMarkdown(unittest.TestCase):
    def test_includes_all_three_cost_rows(self):
        out = report.render_markdown("NA-80", [RUN])
        self.assertIn("impl-only", out)
        self.assertIn("review + fix", out)
        self.assertIn("ceremony", out)

    def test_flags_failed_reconciliation(self):
        run = dict(RUN)
        run["reconciliation"] = {"ok": False}
        self.assertIn("RECONCILIATION FAILED", report.render_markdown("NA-80", [run]))

    def test_clean_run_is_not_flagged(self):
        self.assertNotIn("RECONCILIATION FAILED", report.render_markdown("NA-80", [RUN]))


if __name__ == "__main__":
    unittest.main()
