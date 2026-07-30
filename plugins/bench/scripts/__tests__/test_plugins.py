"""Version pinning: resolve a cached plugin version, pin a project path to it,
and restore the operator's installed_plugins.json exactly as it was.

The file under test is shared with every other Claude Code session on the
machine, so "restores exactly" is a correctness requirement, not a nicety.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import plugins  # noqa: E402


class TestParsePluginKey(unittest.TestCase):
    def test_splits_plugin_and_marketplace(self):
        self.assertEqual(plugins.parse_plugin_key("sdlc@nightshift"), ("sdlc", "nightshift"))

    def test_rejects_key_without_marketplace(self):
        with self.assertRaises(plugins.PluginPinError):
            plugins.parse_plugin_key("sdlc")

    def test_rejects_key_with_two_ats(self):
        with self.assertRaises(plugins.PluginPinError):
            plugins.parse_plugin_key("a@b@c")

    def test_rejects_empty_half(self):
        with self.assertRaises(plugins.PluginPinError):
            plugins.parse_plugin_key("@nightshift")


class TestVersionResolution(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.cache = self.root / "cache"
        (self.cache / "nightshift" / "sdlc" / "0.44.0").mkdir(parents=True)
        (self.cache / "nightshift" / "sdlc" / "0.45.4").mkdir(parents=True)

    def test_install_path_is_marketplace_plugin_version(self):
        self.assertEqual(
            plugins.install_path("sdlc@nightshift", "0.44.0", self.cache),
            self.cache / "nightshift" / "sdlc" / "0.44.0",
        )

    def test_available_versions_sorted(self):
        self.assertEqual(
            plugins.available_versions("sdlc@nightshift", self.cache), ["0.44.0", "0.45.4"]
        )

    def test_present_version_resolves(self):
        self.assertTrue(
            plugins.assert_version_available("sdlc@nightshift", "0.44.0", self.cache).is_dir()
        )

    def test_missing_version_names_what_is_available(self):
        """The cache garbage-collects unreferenced versions, so this is an
        ordinary outcome. The error has to be actionable: it must say what
        can still be benchmarked."""
        with self.assertRaises(plugins.PluginPinError) as ctx:
            plugins.assert_version_available("sdlc@nightshift", "0.31.0", self.cache)
        message = str(ctx.exception)
        self.assertIn("0.31.0", message)
        self.assertIn("0.44.0", message)
        self.assertIn("0.45.4", message)
        self.assertIn("garbage-collect", message)

    def test_unknown_plugin_says_nothing_is_cached(self):
        with self.assertRaises(plugins.PluginPinError) as ctx:
            plugins.assert_version_available("ghost@nightshift", "1.0.0", self.cache)
        self.assertIn("no versions of this plugin are present", str(ctx.exception))


class TestSnapshotRestore(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.path = self.root / "installed_plugins.json"

    def test_snapshot_is_verbatim_text(self):
        """Restoring must be byte-for-byte. Re-serialising parsed JSON would
        silently rewrite key order and indentation in a file this harness
        does not own."""
        original = '{"plugins":   {"a": []}}\n'
        self.path.write_text(original)
        snapshot = plugins.read_snapshot(self.path)
        self.path.write_text('{"clobbered": true}')
        plugins.restore_snapshot(snapshot, self.path)
        self.assertEqual(self.path.read_text(), original)

    def test_missing_file_snapshots_as_none(self):
        self.assertIsNone(plugins.read_snapshot(self.path))

    def test_restoring_a_none_snapshot_removes_the_file(self):
        """If the file did not exist before the run, leaving a
        harness-authored one behind would pin the operator's paths to
        whatever the last cell used."""
        self.path.write_text("{}")
        plugins.restore_snapshot(None, self.path)
        self.assertFalse(self.path.exists())

    def test_restoring_none_when_already_absent_is_not_an_error(self):
        plugins.restore_snapshot(None, self.path)
        self.assertFalse(self.path.exists())


class TestPinEntry(unittest.TestCase):
    def test_rewrites_an_existing_entry_in_place(self):
        """Two entries for one path would leave the winner up to Claude
        Code's resolution order -- not something a measurement may depend
        on."""
        data = {
            "plugins": {
                "sdlc@nightshift": [
                    {"projectPath": "/w", "installPath": "/old", "version": "0.45.4"},
                    {"projectPath": "/other", "installPath": "/keep", "version": "0.23.1"},
                ]
            }
        }
        out = plugins.pin_entry(data, "sdlc@nightshift", "/w", Path("/new"), "0.44.0")
        entries = out["plugins"]["sdlc@nightshift"]
        self.assertEqual(len(entries), 2)
        pinned = [e for e in entries if e["projectPath"] == "/w"][0]
        self.assertEqual(pinned["version"], "0.44.0")
        self.assertEqual(pinned["installPath"], "/new")
        untouched = [e for e in entries if e["projectPath"] == "/other"][0]
        self.assertEqual(untouched["version"], "0.23.1")

    def test_appends_when_no_entry_exists(self):
        out = plugins.pin_entry({}, "sdlc@nightshift", "/w", Path("/new"), "0.44.0")
        entries = out["plugins"]["sdlc@nightshift"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["projectPath"], "/w")
        self.assertEqual(entries[0]["scope"], "project")

    def test_does_not_mutate_the_input(self):
        data = {"plugins": {"sdlc@nightshift": [{"projectPath": "/w", "version": "0.45.4"}]}}
        plugins.pin_entry(data, "sdlc@nightshift", "/w", Path("/new"), "0.44.0")
        self.assertEqual(data["plugins"]["sdlc@nightshift"][0]["version"], "0.45.4")

    def test_leaves_other_plugins_alone(self):
        data = {"plugins": {"gtm@nightshift": [{"projectPath": "/w", "version": "0.5.1"}]}}
        out = plugins.pin_entry(data, "sdlc@nightshift", "/w", Path("/new"), "0.44.0")
        self.assertEqual(out["plugins"]["gtm@nightshift"][0]["version"], "0.5.1")


class TestApplyPin(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.cache = self.root / "cache"
        (self.cache / "nightshift" / "sdlc" / "0.44.0").mkdir(parents=True)
        self.path = self.root / "installed_plugins.json"

    def test_writes_the_pin_and_returns_provenance(self):
        record = plugins.apply_pin(
            "sdlc@nightshift", "0.44.0", "/w", installed_path=self.path, cache_root=self.cache
        )
        written = json.loads(self.path.read_text())
        entry = written["plugins"]["sdlc@nightshift"][0]
        self.assertEqual(entry["version"], "0.44.0")
        self.assertEqual(record["version"], "0.44.0")
        self.assertEqual(record["project_path"], "/w")
        self.assertTrue(record["install_path"].endswith("nightshift/sdlc/0.44.0"))

    def test_missing_version_aborts_before_writing_anything(self):
        with self.assertRaises(plugins.PluginPinError):
            plugins.apply_pin(
                "sdlc@nightshift", "9.9.9", "/w", installed_path=self.path, cache_root=self.cache
            )
        self.assertFalse(self.path.exists())

    def test_malformed_installed_plugins_json_refuses_rather_than_overwrites(self):
        """Overwriting an unparseable file would destroy the operator's
        plugin installation to run a benchmark."""
        self.path.write_text("{not json")
        with self.assertRaises(plugins.PluginPinError) as ctx:
            plugins.apply_pin(
                "sdlc@nightshift", "0.44.0", "/w", installed_path=self.path, cache_root=self.cache
            )
        self.assertIn("not valid JSON", str(ctx.exception))
        self.assertEqual(self.path.read_text(), "{not json")


if __name__ == "__main__":
    unittest.main()


class TestPinBeatsAUserScopeWildcard(unittest.TestCase):
    """A user-scope install has an EMPTY projectPath and matches every project.

    Resolution honours array order, so a pin appended after such an entry is
    written, looks correct in the file, and never takes effect. Demonstrated
    live: pinning superpowers 6.2.0 for a project whose array already held a
    user-scope 6.1.1 entry kept resolving 6.1.1 until the entry was moved to
    the front.
    """

    def _data(self):
        return {
            "plugins": {
                "superpowers@claude-plugins-official": [
                    {"scope": "user", "projectPath": "", "version": "6.1.1",
                     "installPath": "/cache/6.1.1"},
                    {"scope": "project", "projectPath": "/other", "version": "6.0.3",
                     "installPath": "/cache/6.0.3"},
                ]
            }
        }

    def test_new_entry_is_prepended_ahead_of_the_wildcard(self):
        out = plugins.pin_entry(
            self._data(), "superpowers@claude-plugins-official", "/repo",
            Path("/cache/6.2.0"), "6.2.0",
        )
        entries = out["plugins"]["superpowers@claude-plugins-official"]
        self.assertEqual(entries[0]["projectPath"], "/repo")
        self.assertEqual(entries[0]["version"], "6.2.0")
        # The wildcard survives -- it is a legitimate user-scope install.
        self.assertTrue(any(e.get("scope") == "user" for e in entries))

    def test_existing_entry_is_also_moved_to_the_front(self):
        data = self._data()
        data["plugins"]["superpowers@claude-plugins-official"].append(
            {"scope": "project", "projectPath": "/repo", "version": "6.1.1",
             "installPath": "/cache/6.1.1"}
        )
        out = plugins.pin_entry(
            data, "superpowers@claude-plugins-official", "/repo",
            Path("/cache/6.2.0"), "6.2.0",
        )
        entries = out["plugins"]["superpowers@claude-plugins-official"]
        self.assertEqual(entries[0]["projectPath"], "/repo")
        self.assertEqual(entries[0]["version"], "6.2.0")
        # Rewritten in place, not duplicated.
        self.assertEqual(sum(1 for e in entries if e.get("projectPath") == "/repo"), 1)

    def test_no_entries_are_lost(self):
        out = plugins.pin_entry(
            self._data(), "superpowers@claude-plugins-official", "/repo",
            Path("/cache/6.2.0"), "6.2.0",
        )
        self.assertEqual(len(out["plugins"]["superpowers@claude-plugins-official"]), 3)


class TestDurableSnapshotSurvivesAKilledRun(unittest.TestCase):
    """The in-memory restore cannot survive the process being killed.

    It didn't: an interrupted cell left 24 auto-created entries behind, and the
    measured session had already replaced the parent repo's own registrations --
    superpowers silently fell back 6.2.0 -> 6.1.1, context-mode 1.0.162 ->
    1.0.103, and sdlc lost its main-repo entry entirely.
    """

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.installed = self.root / "installed_plugins.json"
        self.snapshot = self.root / ".bench-restore.json"
        self.original = json.dumps({"plugins": {"sdlc@nightshift": [{"version": "0.45.4"}]}})
        self.installed.write_text(self.original)

    def test_snapshot_round_trips_byte_for_byte(self):
        plugins.write_durable_snapshot(self.original, self.snapshot)
        # Simulate the killed run: the file is left rewritten.
        self.installed.write_text('{"plugins": {}}')
        msg = plugins.recover_if_abandoned(self.installed, self.snapshot)
        self.assertIsNotNone(msg)
        self.assertEqual(self.installed.read_text(), self.original)

    def test_recovery_clears_the_marker(self):
        plugins.write_durable_snapshot(self.original, self.snapshot)
        plugins.recover_if_abandoned(self.installed, self.snapshot)
        self.assertFalse(self.snapshot.exists())
        # A second provision must not "recover" again over a healthy file.
        self.assertIsNone(plugins.recover_if_abandoned(self.installed, self.snapshot))

    def test_no_marker_is_a_no_op(self):
        self.assertIsNone(plugins.recover_if_abandoned(self.installed, self.snapshot))
        self.assertEqual(self.installed.read_text(), self.original)

    def test_absent_original_is_recorded_as_null_and_restored_as_absent(self):
        plugins.write_durable_snapshot(None, self.snapshot)
        self.installed.write_text('{"plugins": {}}')
        plugins.recover_if_abandoned(self.installed, self.snapshot)
        self.assertFalse(self.installed.exists())

    def test_unreadable_marker_does_not_touch_installed_plugins(self):
        self.snapshot.write_text("{ not json")
        msg = plugins.recover_if_abandoned(self.installed, self.snapshot)
        self.assertIn("unreadable", msg)
        self.assertEqual(self.installed.read_text(), self.original)

    def test_clear_is_safe_when_nothing_exists(self):
        plugins.clear_durable_snapshot(self.snapshot)  # must not raise
