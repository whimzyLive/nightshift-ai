"""End-to-end behaviour of version-pinned cells across adapters, provision,
execute, measure and report.

The invariant these tests defend: a benchmark row may never be published
under a version it did not actually measure.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import execute  # noqa: E402
import measure  # noqa: E402
import provision  # noqa: E402
import report  # noqa: E402
from benchlib import adapters, plugins  # noqa: E402

VERSIONED_YAML = """
id: sdlc
label: SDLC plugin
version:
  plugin: sdlc@nightshift
  version: 0.44.0
run:
  model: claude-opus-5
  prompt: |
    do {{ticket_key}}
"""

UNVERSIONED_YAML = """
id: opus
label: Direct Opus
run:
  model: claude-opus-5
  prompt: |
    do {{ticket_key}}
"""


def _write(path, text):
    path.write_text(text)
    return path


class TestAdapterVersionBlock(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def test_version_block_is_parsed(self):
        adapter = adapters.load_adapter(_write(self.root / "a.yaml", VERSIONED_YAML))
        self.assertEqual(adapter.version.plugin, "sdlc@nightshift")
        self.assertEqual(adapter.version.version, "0.44.0")

    def test_cell_id_carries_the_version(self):
        adapter = adapters.load_adapter(_write(self.root / "a.yaml", VERSIONED_YAML))
        self.assertEqual(adapter.cell_id, "sdlc@0.44.0")

    def test_unversioned_adapter_keeps_its_bare_id(self):
        adapter = adapters.load_adapter(_write(self.root / "b.yaml", UNVERSIONED_YAML))
        self.assertIsNone(adapter.version)
        self.assertEqual(adapter.cell_id, "opus")

    def test_half_declared_pin_is_rejected(self):
        """A block naming a plugin but no version reads as a pin while
        measuring whatever is installed."""
        yaml = VERSIONED_YAML.replace("  version: 0.44.0\n", "")
        with self.assertRaises(ValueError) as ctx:
            adapters.load_adapter(_write(self.root / "c.yaml", yaml))
        self.assertIn("version", str(ctx.exception))

    def test_non_mapping_version_is_rejected(self):
        yaml = UNVERSIONED_YAML + "version: 0.44.0\n"
        with self.assertRaises(ValueError):
            adapters.load_adapter(_write(self.root / "d.yaml", yaml))


class TestProvisionCellId(unittest.TestCase):
    def test_version_namespaces_the_cell(self):
        self.assertEqual(provision.cell_id("sdlc", "0.44.0"), "sdlc@0.44.0")

    def test_absent_version_leaves_the_id_bare(self):
        self.assertEqual(provision.cell_id("opus", None), "opus")

    def test_matches_the_adapter_form(self):
        """provision.py and adapters.py compute this independently; if they
        ever disagree, execute.py's cross-check fires on every run."""
        root = Path(tempfile.mkdtemp())
        adapter = adapters.load_adapter(_write(root / "a.yaml", VERSIONED_YAML))
        self.assertEqual(provision.cell_id("sdlc", "0.44.0"), adapter.cell_id)

    def test_versioned_branch_passes_the_bench_guard(self):
        """`@` and `.` are legal in refs; the guard must not reject a
        versioned cell's branch."""
        branch = provision.branch_name("NA-68", provision.cell_id("sdlc", "0.44.0"), "r1")
        self.assertEqual(branch, "bench/NA-68/sdlc@0.44.0/r1")
        provision.assert_bench_branch(branch)


class TestCellAdapterCrossCheck(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.adapter = adapters.load_adapter(_write(self.root / "a.yaml", VERSIONED_YAML))

    def test_matching_cell_passes(self):
        execute.assert_cell_matches_adapter(
            {"approach": "sdlc@0.44.0", "version": "0.44.0"}, self.adapter
        )

    def test_identity_mismatch_is_refused(self):
        with self.assertRaises(plugins.PluginPinError) as ctx:
            execute.assert_cell_matches_adapter(
                {"approach": "sdlc@0.45.4", "version": "0.45.4"}, self.adapter
            )
        self.assertIn("mismatch", str(ctx.exception))

    def test_version_mismatch_alone_is_refused(self):
        with self.assertRaises(plugins.PluginPinError):
            execute.assert_cell_matches_adapter(
                {"approach": "sdlc@0.44.0", "version": "0.45.4"}, self.adapter
            )

    def test_unversioned_cell_against_unversioned_adapter_passes(self):
        adapter = adapters.load_adapter(_write(self.root / "b.yaml", UNVERSIONED_YAML))
        execute.assert_cell_matches_adapter({"approach": "opus", "version": None}, adapter)


class TestPinIsAlwaysRestored(unittest.TestCase):
    """installed_plugins.json is shared with every other session on the
    machine. No exit path may leave it rewritten."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.cache = self.root / "cache"
        (self.cache / "nightshift" / "sdlc" / "0.44.0").mkdir(parents=True)
        self.installed = self.root / "installed_plugins.json"
        self.original = json.dumps(
            {"plugins": {"sdlc@nightshift": [{"projectPath": "/repo", "version": "0.45.4"}]}},
            indent=2,
        )
        self.installed.write_text(self.original)

        self.path_patch = patch.multiple(
            plugins, INSTALLED_PLUGINS_PATH=self.installed, CACHE_ROOT=self.cache
        )
        self.path_patch.start()
        self.addCleanup(self.path_patch.stop)

    def _run_main(self):
        cell = self.root / "cell.json"
        cell.write_text(
            json.dumps(
                {
                    "approach": "sdlc@0.44.0",
                    "approach_id": "sdlc",
                    "version": "0.44.0",
                    "repo": str(self.root),
                    "worktree": str(self.root / "wt"),
                    "artifacts": str(self.root / "art"),
                }
            )
        )
        (self.root / "art").mkdir(exist_ok=True)
        story = self.root / "story.json"
        story.write_text(
            json.dumps({"key": "NA-1", "summary": "S", "description": "D", "acs": "- a"})
        )
        adapter = _write(self.root / "a.yaml", VERSIONED_YAML)
        return execute.main(
            [
                "--cell", str(cell),
                "--story", str(story),
                "--adapter", str(adapter),
                "--out", str(self.root / "result.json"),
            ]
        )

    def test_restored_after_a_mid_run_exception(self):
        """The failure path matters more than the happy one: an exception is
        exactly when a teardown hook would have been skipped."""
        with patch.object(execute.config, "load_config", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                self._run_main()
        self.assertEqual(self.installed.read_text(), self.original)

    def test_restored_after_a_failing_setup_hook(self):
        with patch.object(execute, "run_hooks", side_effect=RuntimeError("hook died")):
            with patch.object(execute.config, "require_command", return_value="pytest"):
                with self.assertRaises(RuntimeError):
                    self._run_main()
        self.assertEqual(self.installed.read_text(), self.original)

    def test_pin_is_actually_applied_while_the_session_runs(self):
        """Proves the restore test above is not passing vacuously: the pin
        must genuinely be in place at the moment `claude` is invoked."""
        seen = {}

        def fake_run(argv, **kwargs):
            seen["installed"] = json.loads(self.installed.read_text())
            raise RuntimeError("stop here")

        with patch.object(execute.config, "require_command", return_value="pytest"):
            with patch.object(execute, "run_hooks"):
                with patch.object(execute.subprocess, "run", side_effect=fake_run):
                    with self.assertRaises(RuntimeError):
                        self._run_main()

        entries = seen["installed"]["plugins"]["sdlc@nightshift"]
        pinned = [e for e in entries if e["projectPath"] == str(self.root / "wt")]
        self.assertEqual(len(pinned), 1)
        self.assertEqual(pinned[0]["version"], "0.44.0")
        # ...and it is gone again afterwards.
        self.assertEqual(self.installed.read_text(), self.original)

    def test_missing_cached_version_aborts_before_touching_the_file(self):
        yaml = VERSIONED_YAML.replace("0.44.0", "9.9.9")
        _write(self.root / "a.yaml", yaml)
        cell = self.root / "cell.json"
        cell.write_text(
            json.dumps(
                {
                    "approach": "sdlc@9.9.9",
                    "version": "9.9.9",
                    "repo": str(self.root),
                    "worktree": str(self.root / "wt"),
                    "artifacts": str(self.root / "art"),
                }
            )
        )
        story = self.root / "story.json"
        story.write_text(
            json.dumps({"key": "NA-1", "summary": "S", "description": "D", "acs": "- a"})
        )
        with self.assertRaises(plugins.PluginPinError):
            execute.main(
                [
                    "--cell", str(cell),
                    "--story", str(story),
                    "--adapter", str(self.root / "a.yaml"),
                    "--out", str(self.root / "result.json"),
                ]
            )
        self.assertEqual(self.installed.read_text(), self.original)


class TestResolvedVersionFromTranscript(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.transcript = self.root / "t.jsonl"

    def _transcript(self, text):
        self.transcript.write_text(json.dumps({"type": "system", "content": text}) + "\n")
        return self.transcript

    def test_recovers_plugin_and_version_from_the_root_announcement(self):
        path = self._transcript(
            "SDLC plugin root (this session): "
            "/Users/x/.claude/plugins/cache/nightshift/sdlc/0.45.4\n"
        )
        found = measure.resolved_plugin_versions(path)
        self.assertEqual(found["sdlc@nightshift"]["version"], "0.45.4")

    def test_recovers_several_plugins(self):
        path = self._transcript(
            "SDLC plugin root (this session): /c/nightshift/sdlc/0.44.0\n"
            "gtm plugin root (this session): /c/nightshift/gtm/0.5.1\n"
        )
        found = measure.resolved_plugin_versions(path)
        self.assertEqual(found["sdlc@nightshift"]["version"], "0.44.0")
        self.assertEqual(found["gtm@nightshift"]["version"], "0.5.1")

    def test_transcript_without_announcements_yields_nothing(self):
        found = measure.resolved_plugin_versions(self._transcript("ordinary text"))
        self.assertEqual(found, {})

    def test_missing_transcript_yields_nothing(self):
        self.assertEqual(measure.resolved_plugin_versions(self.root / "nope.jsonl"), {})
        self.assertEqual(measure.resolved_plugin_versions(None), {})


class TestPluginVersionVerdict(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.transcript = self.root / "t.jsonl"

    def _with(self, version):
        self.transcript.write_text(
            json.dumps(
                {
                    "content": "SDLC plugin root (this session): "
                    "/c/nightshift/sdlc/{0}".format(version)
                }
            )
        )
        return self.transcript

    def _result(self, version):
        return {"plugin_version": {"declared": {"plugin": "sdlc@nightshift", "version": version}}}

    def test_no_pin_declared_is_ok_and_unverified(self):
        verdict = measure.plugin_version_verdict({}, self._with("0.45.4"))
        self.assertTrue(verdict["ok"])
        self.assertFalse(verdict["verified"])
        self.assertIsNone(verdict["declared"])
        # Still recorded: knowing what ran is useful even with nothing pinned.
        self.assertEqual(verdict["resolved"]["sdlc@nightshift"]["version"], "0.45.4")

    def test_agreement_is_verified(self):
        verdict = measure.plugin_version_verdict(self._result("0.44.0"), self._with("0.44.0"))
        self.assertTrue(verdict["ok"])
        self.assertTrue(verdict["verified"])

    def test_disagreement_fails_the_cell(self):
        """A row reporting 0.44.0's cost under 0.45.4's name inverts the
        conclusion the operator is trying to reach."""
        verdict = measure.plugin_version_verdict(self._result("0.45.4"), self._with("0.44.0"))
        self.assertFalse(verdict["ok"])
        self.assertTrue(verdict["verified"])
        self.assertIn("VERSION MISMATCH", verdict["note"])
        self.assertIn("0.44.0", verdict["note"])

    def test_silent_plugin_is_unverified_but_not_a_failure(self):
        """Absence of the hook is not evidence of the wrong version."""
        self.transcript.write_text("{}")
        verdict = measure.plugin_version_verdict(self._result("0.44.0"), self.transcript)
        self.assertTrue(verdict["ok"])
        self.assertFalse(verdict["verified"])
        self.assertIn("could not be independently", verdict["note"])


def _run(approach, version=None, resolved=None, ok=True, verified=True, total=1.0, impl=0.8):
    """A minimal run.json good enough for report rendering."""
    plugin_version = {
        "declared": {"plugin": "sdlc@nightshift", "version": version} if version else None,
        "resolved": (
            {"sdlc@nightshift": {"version": resolved or version, "install_path": "/c"}}
            if resolved or (version and verified)
            else {}
        ),
        "ok": ok,
        "verified": verified,
        "note": "note for {0}".format(approach),
    }
    return {
        "ticket": "NA-1",
        "approach": approach,
        "approach_id": approach.split("@")[0],
        "version": version,
        "plugin_version": plugin_version,
        "run_id": "r1",
        "total": {"reported_cost_usd": total, "duration_ms": 1000},
        "by_phase": {"impl": {"cost_usd": impl}},
        "grades": {"acs": {"AC1": {"met": True}}, "findings_count": 2, "regressions": False},
        "reconciliation": {"ok": True},
        "phase_attribution": {"available": True},
        "work_done": {"empty_diff": False},
        "termination": {"clean": True},
    }


class TestReportVersionColumn(unittest.TestCase):
    def test_version_column_shows_what_ran(self):
        out = report.render_markdown("NA-1", [_run("sdlc@0.44.0", "0.44.0")])
        self.assertIn("| Version  |", out)
        self.assertIn("0.44.0", out)

    def test_unversioned_row_shows_a_dash(self):
        out = report.render_markdown("NA-1", [_run("opus")])
        rows = [line for line in out.splitlines() if line.startswith("| OK")]
        self.assertIn("—", rows[0])

    def test_mismatch_renders_wrong_ver_with_the_version_that_actually_ran(self):
        run = _run("sdlc@0.45.4", "0.45.4", resolved="0.44.0", ok=False)
        out = report.render_markdown("NA-1", [run])
        self.assertIn("WRONG VER", out)
        # The column must show what ran, not what was asked for -- otherwise
        # it restates the mislabelling the status is warning about.
        row = [line for line in out.splitlines() if "WRONG VER" in line][0]
        self.assertIn("0.44.0 !", row)
        self.assertIn("## Version provenance", out)

    def test_unverifiable_pin_is_marked_but_stays_ok(self):
        run = _run("sdlc@0.44.0", "0.44.0", verified=False)
        out = report.render_markdown("NA-1", [run])
        row = [line for line in out.splitlines() if line.startswith("| OK")][0]
        self.assertIn("0.44.0 ?", row)
        self.assertIn("## Version provenance", out)


class TestReportBaseline(unittest.TestCase):
    def test_no_baseline_renders_no_delta_section(self):
        out = report.render_markdown("NA-1", [_run("sdlc@0.44.0", "0.44.0")])
        self.assertNotIn("Compared against", out)

    def test_deltas_are_signed_relative_to_the_baseline(self):
        runs = [
            _run("sdlc@0.44.0", "0.44.0", total=1.00, impl=0.80),
            _run("sdlc@0.45.4", "0.45.4", total=1.50, impl=1.20),
        ]
        out = report.render_markdown("NA-1", runs, baseline="sdlc@0.44.0")
        self.assertIn("## Compared against `sdlc@0.44.0`", out)
        row = [line for line in out.splitlines() if "sdlc@0.45.4" in line and "+" in line][0]
        self.assertIn("+0.50", row)
        self.assertIn("+0.40", row)
        self.assertIn("+50.0%", row)
        # The baseline is not differenced against itself.
        self.assertEqual(
            len([line for line in out.splitlines() if line.startswith("| sdlc@0.44.0")]), 0
        )

    def test_unknown_baseline_says_so_and_lists_what_exists(self):
        out = report.render_markdown("NA-1", [_run("opus")], baseline="sdlc@0.44.0")
        self.assertIn("No row named `sdlc@0.44.0` is present", out)
        self.assertIn("opus", out)

    def test_non_comparable_row_is_dashed_not_differenced(self):
        bad = _run("sdlc@0.45.4", "0.45.4")
        bad["termination"] = {"clean": False, "violations": [], "note": "cut off"}
        out = report.render_markdown(
            "NA-1", [_run("sdlc@0.44.0", "0.44.0"), bad], baseline="sdlc@0.44.0"
        )
        row = [
            line
            for line in out.splitlines()
            if line.startswith("| sdlc@0.45.4") and "—" in line
        ]
        self.assertTrue(row)

    def test_unusable_baseline_refuses_to_compute_deltas(self):
        base = _run("sdlc@0.44.0", "0.44.0")
        base["reconciliation"] = {"ok": False, "note": "drifted"}
        out = report.render_markdown(
            "NA-1", [base, _run("sdlc@0.45.4", "0.45.4")], baseline="sdlc@0.44.0"
        )
        self.assertIn("does not carry a usable measurement", out)

    def test_variance_caveat_is_always_stated(self):
        """A delta smaller than the sampling spread is not a result, and a
        single run per cell has no spread estimate."""
        out = report.render_markdown(
            "NA-1",
            [_run("sdlc@0.44.0", "0.44.0"), _run("sdlc@0.45.4", "0.45.4")],
            baseline="sdlc@0.44.0",
        )
        self.assertIn("no variance estimate", out)


class TestRepeatRuns(unittest.TestCase):
    def test_nested_run_id_layout_is_collected(self):
        """Repeats live at <cell>/<run_id>/run.json so each run keeps its own
        evidence; the older flat layout must keep working too."""
        root = Path(tempfile.mkdtemp())
        ticket = root / "NA-1"
        flat = ticket / "opus"
        flat.mkdir(parents=True)
        (flat / "run.json").write_text(json.dumps(_run("opus")))
        nested = ticket / "sdlc@0.44.0" / "r2"
        nested.mkdir(parents=True)
        (nested / "run.json").write_text(json.dumps(_run("sdlc@0.44.0", "0.44.0")))

        collected = report.collect_runs(ticket)
        self.assertEqual(
            sorted(r["approach"] for r in collected), ["opus", "sdlc@0.44.0"]
        )

    def test_single_run_per_cell_reports_no_spread(self):
        rows = report.phase_rows([_run("sdlc@0.44.0", "0.44.0")])
        self.assertEqual(report.spread_by_approach(rows), {})

    def test_repeats_produce_a_noise_floor(self):
        runs = [
            _run("sdlc@0.44.0", "0.44.0", total=1.00),
            _run("sdlc@0.44.0", "0.44.0", total=1.30),
        ]
        out = report.render_markdown("NA-1", runs)
        self.assertIn("## Repeat runs — the noise floor", out)
        row = [line for line in out.splitlines() if line.startswith("| sdlc@0.44.0 ")][-1]
        self.assertIn("0.30", row)  # spread
        self.assertIn("1.15", row)  # mean

    def test_a_cut_off_repeat_is_excluded_from_the_mean(self):
        """Averaging a truncated run in would drag the mean toward a number
        no session actually produced."""
        bad = _run("sdlc@0.44.0", "0.44.0", total=0.10)
        bad["termination"] = {"clean": False, "violations": [], "note": "cut off"}
        rows = report.phase_rows(
            [_run("sdlc@0.44.0", "0.44.0", total=1.00), _run("sdlc@0.44.0", "0.44.0", total=1.30), bad]
        )
        stat = report.spread_by_approach(rows)["sdlc@0.44.0"]
        self.assertEqual(stat["n"], 2)
        self.assertAlmostEqual(stat["mean"], 1.15)

    def test_baseline_differences_against_the_mean_of_repeats(self):
        runs = [
            _run("sdlc@0.44.0", "0.44.0", total=1.00, impl=0.80),
            _run("sdlc@0.44.0", "0.44.0", total=1.20, impl=1.00),
            _run("sdlc@0.45.4", "0.45.4", total=1.60, impl=1.40),
        ]
        out = report.render_markdown("NA-1", runs, baseline="sdlc@0.44.0")
        row = [
            line
            for line in out.splitlines()
            if line.startswith("| sdlc@0.45.4") and "%" in line
        ][0]
        # baseline mean total is 1.10, so the delta is +0.50, not +0.60/+0.40
        self.assertIn("+0.50", row)

    def test_noise_floor_replaces_the_no_variance_caveat(self):
        runs = [
            _run("sdlc@0.44.0", "0.44.0", total=1.00),
            _run("sdlc@0.44.0", "0.44.0", total=1.30),
            _run("sdlc@0.45.4", "0.45.4", total=1.60),
        ]
        out = report.render_markdown("NA-1", runs, baseline="sdlc@0.44.0")
        self.assertIn("varied by up to **0.30 API-eq $**", out)
        self.assertNotIn("no variance estimate", out)


if __name__ == "__main__":
    unittest.main()
