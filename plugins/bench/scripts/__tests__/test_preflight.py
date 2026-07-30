"""The sweep preflight — the call site the quota guard was missing.

`benchlib/quota.py` shipped with tests and no caller, so the guard the founder
asked for did not guard anything. These tests exist to keep that from being
true again: they exercise the CLI, not just the module.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import preflight  # noqa: E402
from benchlib import quota  # noqa: E402

APPROACHES = Path(__file__).resolve().parents[2] / "approaches"
OPUS = str(APPROACHES / "opus.yaml")
SDLC = str(APPROACHES / "sdlc-0.45.4.yaml")


class TestSweepArithmetic(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.mkdtemp())

    def _run(self, argv):
        return preflight.main(argv)

    def test_ordinary_sweep_proceeds(self):
        code = self._run(
            ["--ticket", "NA-68", "--repo", str(self.repo), "--adapter", OPUS]
        )
        self.assertEqual(code, 0)

    def test_cell_cap_refuses_with_exit_2(self):
        # Distinct from 1 so a caller can tell a refusal from a crash.
        code = self._run(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", OPUS, "--repeats", "50", "--max-cells", "24",
            ]
        )
        self.assertEqual(code, 2)

    def test_acknowledgement_does_not_clear_the_cell_cap(self):
        code = self._run(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", OPUS, "--repeats", "50", "--max-cells", "24",
                "--acknowledge-cost",
            ]
        )
        self.assertEqual(code, 2)

    def test_cost_threshold_refuses_then_clears_on_acknowledgement(self):
        argv = [
            "--ticket", "NA-68", "--repo", str(self.repo),
            "--adapter", OPUS, "--adapter", SDLC,
            "--repeats", "4", "--threshold-usd", "1.0",
        ]
        self.assertEqual(self._run(argv), 2)
        self.assertEqual(self._run(argv + ["--acknowledge-cost"]), 0)

    def test_zero_repeats_is_refused_not_treated_as_free(self):
        code = self._run(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", OPUS, "--repeats", "0",
            ]
        )
        self.assertEqual(code, 2)


class TestHistoryDrivesTheForecast(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.mkdtemp())

    def _write_run(self, cell, cost):
        d = self.repo / "docs" / "benchmarks" / "NA-68" / cell / "r1"
        d.mkdir(parents=True, exist_ok=True)
        (d / "run.json").write_text(
            json.dumps({"approach": cell, "total": {"reported_cost_usd": cost}})
        )

    def test_no_history_is_not_an_error(self):
        self.assertEqual(preflight.collect_history(self.repo, "NA-68"), [])

    def test_history_is_read_and_used(self):
        self._write_run("opus", 7.0)
        self._write_run("sdlc@0.45.4", 9.0)
        history = preflight.collect_history(self.repo, "NA-68")
        self.assertEqual(len(history), 2)
        self.assertEqual(quota.measured_per_cell_usd(history), 8.0)

    def test_measured_history_changes_the_verdict(self):
        # $8/cell measured x 2 cells = $16, over a $10 threshold, where the
        # default per-cell figure would have passed.
        self._write_run("opus", 8.0)
        code = preflight.main(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", OPUS, "--repeats", "2", "--threshold-usd", "10.0",
            ]
        )
        self.assertEqual(code, 2)

    def test_unreadable_history_does_not_abort(self):
        d = self.repo / "docs" / "benchmarks" / "NA-68" / "opus" / "r1"
        d.mkdir(parents=True)
        (d / "run.json").write_text("{ not json")
        # A corrupt record must not stop a sweep that has not started; the
        # forecast falls back to the default rather than crashing.
        self.assertEqual(
            preflight.main(
                ["--ticket", "NA-68", "--repo", str(self.repo), "--adapter", OPUS]
            ),
            0,
        )


class TestBlastRadiusIsStated(unittest.TestCase):
    """Cost and blast radius are separate: budget does not undo a Jira issue."""

    def setUp(self):
        self.repo = Path(tempfile.mkdtemp())

    def _out(self, argv):
        proc = subprocess.run(
            [sys.executable, str(Path(preflight.__file__))] + argv,
            capture_output=True,
            text=True,
        )
        return proc.stdout

    def test_jira_writing_approach_announces_what_it_creates(self):
        out = self._out(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", SDLC, "--repeats", "2",
            ]
        )
        self.assertIn("WILL CREATE: 2 Jira issue(s)", out)
        self.assertIn("/bench:cleanup NA-68", out)

    def test_read_only_approach_says_it_creates_nothing(self):
        out = self._out(
            ["--ticket", "NA-68", "--repo", str(self.repo), "--adapter", OPUS]
        )
        self.assertIn("no Jira issues or pull requests", out)

    def test_plugin_set_is_shown_per_approach(self):
        out = self._out(
            [
                "--ticket", "NA-68", "--repo", str(self.repo),
                "--adapter", OPUS, "--adapter", SDLC,
            ]
        )
        self.assertIn("plugins: none", out)
        self.assertIn("sdlc@nightshift", out)

    def test_default_basis_admits_it_is_not_a_quote(self):
        out = self._out(
            ["--ticket", "NA-68", "--repo", str(self.repo), "--adapter", OPUS]
        )
        self.assertIn("not a quote", out)


if __name__ == "__main__":
    unittest.main()
