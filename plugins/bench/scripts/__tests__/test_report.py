import sys
import unittest
from pathlib import Path
import tempfile
import shutil
import json
import copy

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
        run = copy.deepcopy(RUN)
        run["reconciliation"] = {"ok": False, "note": "per-phase sum drifted"}
        out = report.render_markdown("NA-80", [run])
        self.assertIn("| FAILED", out)
        self.assertIn("Failed reconciliations", out)

    def test_clean_run_is_not_flagged(self):
        out = report.render_markdown("NA-80", [RUN])
        self.assertIn("| OK", out)
        self.assertNotIn("Failed reconciliations", out)

    def test_failed_row_renders_phase_costs_as_em_dash(self):
        run = copy.deepcopy(RUN)
        run["reconciliation"] = {"ok": False}
        out = report.render_markdown("NA-80", [run])
        # Find the data row (not the header)
        lines = out.split("\n")
        data_lines = [l for l in lines if l.startswith("| FAILED")]
        self.assertTrue(len(data_lines) > 0)
        # Check for em dashes in place of costs
        self.assertIn("—", data_lines[0])

    def test_regressions_column_present(self):
        out = report.render_markdown("NA-80", [RUN])
        self.assertIn("Regressions", out)

    def test_grader_failure_shown_in_acs(self):
        run = copy.deepcopy(RUN)
        run["grades"]["grader_failure_count"] = 1
        out = report.render_markdown("NA-80", [run])
        self.assertIn("fail", out.lower())


class TestCollectRuns(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_collect_runs_happy_path(self):
        approach_dir = Path(self.tmpdir) / "approach1"
        approach_dir.mkdir()
        run_data = {"approach": "test", "total": {"reported_cost_usd": 10.0}, "by_phase": {}}
        (approach_dir / "run.json").write_text(json.dumps(run_data))
        grades_data = {"acs": {}, "findings_count": 0}
        (approach_dir / "grades.json").write_text(json.dumps(grades_data))

        runs = report.collect_runs(Path(self.tmpdir))
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0]["approach"], "test")
        self.assertEqual(runs[0]["grades"]["findings_count"], 0)

    def test_collect_runs_missing_grades_json(self):
        approach_dir = Path(self.tmpdir) / "approach1"
        approach_dir.mkdir()
        run_data = {"approach": "test", "total": {"reported_cost_usd": 10.0}, "by_phase": {}}
        (approach_dir / "run.json").write_text(json.dumps(run_data))

        runs = report.collect_runs(Path(self.tmpdir))
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0]["grades"], {})

    def test_collect_runs_malformed_json(self):
        approach_dir = Path(self.tmpdir) / "approach1"
        approach_dir.mkdir()
        (approach_dir / "run.json").write_text("{ invalid json")

        runs = report.collect_runs(Path(self.tmpdir))
        # Should skip the malformed file
        self.assertTrue(any("_file_skipped" in r for r in runs))

    def test_collect_runs_malformed_grades(self):
        approach_dir = Path(self.tmpdir) / "approach1"
        approach_dir.mkdir()
        run_data = {"approach": "test", "total": {"reported_cost_usd": 10.0}, "by_phase": {}}
        (approach_dir / "run.json").write_text(json.dumps(run_data))
        (approach_dir / "grades.json").write_text("{ invalid json")

        runs = report.collect_runs(Path(self.tmpdir))
        # Should skip when grades is malformed
        self.assertTrue(any("_file_skipped" in r for r in runs))


class TestArtifactInventory(unittest.TestCase):
    def test_artifact_inventory_includes_ceremony_phases(self):
        runs = [RUN]
        inventory = report.artifact_inventory(runs)
        # Should include spec, plan, docs (not impl, not review-fix)
        self.assertEqual(len(inventory), 3)
        phases = [item["phase"] for item in inventory]
        self.assertIn("spec", phases)
        self.assertIn("plan", phases)
        self.assertIn("docs", phases)

    def test_artifact_inventory_empty_when_no_ceremony(self):
        run = {
            "approach": "minimal",
            "total": {"reported_cost_usd": 10.0},
            "by_phase": {"impl": {"cost_usd": 10.0}},
            "reconciliation": {"ok": True},
        }
        inventory = report.artifact_inventory([run])
        self.assertEqual(len(inventory), 0)

    def test_artifact_inventory_excludes_failed_rows(self):
        run = copy.deepcopy(RUN)
        run["reconciliation"] = {"ok": False}
        inventory = report.artifact_inventory([run])
        self.assertEqual(len(inventory), 0)

    def test_artifact_inventory_unknown_phase_in_ceremony(self):
        run = copy.deepcopy(RUN)
        run["by_phase"]["custom-phase"] = {"cost_usd": 5.0}
        inventory = report.artifact_inventory([run])
        # Should include custom-phase in ceremony
        phases = [item["phase"] for item in inventory]
        self.assertIn("custom-phase", phases)


class TestPhaseRowsExtended(unittest.TestCase):
    def test_unknown_phase_lands_in_ceremony(self):
        run = {
            "approach": "test",
            "total": {"reported_cost_usd": 25.0, "duration_ms": 1000},
            "by_phase": {
                "impl": {"cost_usd": 10.0},
                "custom-phase": {"cost_usd": 15.0},
            },
            "reconciliation": {"ok": True},
            "grades": {"acs": {}, "findings_count": 0},
        }
        row = report.phase_rows([run])[0]
        # custom-phase should be included in ceremony
        self.assertAlmostEqual(row["ceremony"], 15.0)

    def test_phase_rows_includes_regressions(self):
        run = copy.deepcopy(RUN)
        run["grades"]["regressions"] = True
        row = report.phase_rows([run])[0]
        self.assertTrue(row["regressions"])

    def test_phase_rows_includes_grader_failure_count(self):
        run = copy.deepcopy(RUN)
        run["grades"]["grader_failure_count"] = 2
        row = report.phase_rows([run])[0]
        self.assertEqual(row["grader_failure_count"], 2)

    def test_phase_rows_includes_reconciliation_note(self):
        run = copy.deepcopy(RUN)
        run["reconciliation"] = {"ok": False, "note": "test note"}
        row = report.phase_rows([run])[0]
        self.assertEqual(row["reconciliation_note"], "test note")


if __name__ == "__main__":
    unittest.main()
