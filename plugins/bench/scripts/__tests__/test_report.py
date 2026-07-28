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


class TestPhaseAttributionRendering(unittest.TestCase):
    """A row whose markers never fired must not print a split (finding C3)."""

    def _run(self, **attribution):
        run = copy.deepcopy(RUN)
        run["phase_attribution"] = attribution
        return run

    def test_multi_phase_no_marker_fired_renders_em_dashes(self):
        run = self._run(
            declared_phases=["spec", "impl", "review-fix"],
            marker_fires={"spec": 0, "impl": 0, "review-fix": 0},
            any_marker_fired=False,
            available=False,
            note="phase attribution unavailable: 3 phases declared",
        )
        md = report.render_markdown("NA-80", [run])
        # The fabricated impl-only figure must not appear.
        self.assertNotIn("30.00", md)
        self.assertIn("NO SPLIT", md)
        self.assertIn("—", md)
        # The total is still a real measurement and must survive.
        self.assertIn("46.67", md)

    def test_multi_phase_no_marker_fired_adds_a_footnote(self):
        run = self._run(
            declared_phases=["spec", "impl"],
            marker_fires={"spec": 0, "impl": 0},
            any_marker_fired=False,
            available=False,
            note="no phase marker matched anywhere in the transcript",
        )
        md = report.render_markdown("NA-80", [run])
        self.assertIn("## Phase attribution unavailable", md)
        self.assertIn("no phase marker matched", md)

    def test_single_declared_phase_with_empty_marker_still_renders(self):
        # opus.yaml's shape: one phase, no marker needed. NOT the broken case.
        run = {
            "approach": "opus",
            "total": {"reported_cost_usd": 9.71, "duration_ms": 1000},
            "by_phase": {"impl": {"cost_usd": 9.71}},
            "reconciliation": {"ok": True},
            "phase_attribution": {
                "declared_phases": ["impl"],
                "marker_fires": {"impl": 0},
                "any_marker_fired": False,
                "available": True,
                "note": "",
            },
            "grades": {"acs": {"AC1": {"met": True}}, "findings_count": 0},
        }
        md = report.render_markdown("NA-80", [run])
        self.assertIn("9.71", md)
        self.assertNotIn("NO SPLIT", md)
        self.assertNotIn("## Phase attribution unavailable", md)

    def test_marker_that_fired_renders_normally(self):
        run = self._run(
            declared_phases=["spec", "impl"],
            marker_fires={"spec": 1, "impl": 4},
            any_marker_fired=True,
            available=True,
            note="",
        )
        md = report.render_markdown("NA-80", [run])
        self.assertIn("30.00", md)
        self.assertNotIn("NO SPLIT", md)

    def test_unattributed_row_is_excluded_from_the_artifact_inventory(self):
        run = self._run(
            declared_phases=["spec", "impl"],
            marker_fires={"spec": 0, "impl": 0},
            any_marker_fired=False,
            available=False,
            note="",
        )
        self.assertEqual(report.artifact_inventory([run]), [])

    def test_run_json_without_phase_attribution_is_treated_as_available(self):
        md = report.render_markdown("NA-80", [copy.deepcopy(RUN)])
        self.assertIn("30.00", md)
        self.assertNotIn("NO SPLIT", md)


class TestEmptyDiffRendering(unittest.TestCase):
    """A cell with no code change is a failed cell (finding C4)."""

    def _empty_diff_run(self):
        run = copy.deepcopy(RUN)
        run["work_done"] = {
            "files_touched": 0,
            "lines_added": 0,
            "lines_removed": 0,
            "edit_calls": 7,
            "write_calls": 1,
            "empty_diff": True,
            "empty_diff_note": "no code change: git diff base..HEAD is empty",
        }
        run["grades"] = {"acs": {}, "findings_count": 0, "regressions": False}
        return run

    def test_status_says_no_diff(self):
        md = report.render_markdown("NA-80", [self._empty_diff_run()])
        self.assertIn("NO DIFF", md)

    def test_zero_findings_is_not_rendered_as_a_clean_result(self):
        md = report.render_markdown("NA-80", [self._empty_diff_run()])
        table = [ln for ln in md.splitlines() if ln.startswith("| NO DIFF")][0]
        # ACs and findings must be em dashes, never "0/0" and "0".
        self.assertNotIn("0/0", table)
        self.assertIn("—", table)

    def test_adds_a_failed_cell_footnote(self):
        md = report.render_markdown("NA-80", [self._empty_diff_run()])
        self.assertIn("## Failed cells — no code change", md)
        self.assertIn("no code change", md)

    def test_a_cell_with_a_diff_renders_normally(self):
        run = copy.deepcopy(RUN)
        run["work_done"] = {"files_touched": 4, "empty_diff": False, "empty_diff_note": ""}
        md = report.render_markdown("NA-80", [run])
        self.assertNotIn("NO DIFF", md)
        self.assertNotIn("## Failed cells", md)
