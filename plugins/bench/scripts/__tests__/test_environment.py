"""Plugin isolation, adapter permissions, and tool-call phase markers.

The defect these cover: a bench worktree is a checkout of the subject repo,
so it inherits that repo's committed `.claude/settings.json` and the
operator's `~/.claude/settings.json`. Before this, a cell labelled "Direct
Opus, no framework" ran with the SDLC plugin and superpowers loaded. Every
test here exists to keep a row's label and its session in agreement.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import measure  # noqa: E402
import provision  # noqa: E402
import report  # noqa: E402
from benchlib import adapters, environment  # noqa: E402

APPROACHES = Path(__file__).resolve().parents[2] / "approaches"

BASE_YAML = """
id: demo
label: Demo
plugins:
  enable: []
run:
  model: claude-opus-5
  prompt: |
    do {{ticket_key}}
"""


def _write(root, text, name="a.yaml"):
    path = Path(root) / name
    path.write_text(text)
    return path


class TestAdapterPluginBlock(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def test_empty_enable_list_is_valid_and_distinct_from_absent(self):
        adapter = adapters.load_adapter(_write(self.root, BASE_YAML))
        self.assertEqual(adapter.plugins, [])

    def test_absent_block_is_rejected(self):
        # The whole point: omission must not be readable as "no plugins",
        # because omission is what silently inherits the operator's set.
        yaml = BASE_YAML.replace("plugins:\n  enable: []\n", "")
        with self.assertRaisesRegex(ValueError, r"no `plugins:` block"):
            adapters.load_adapter(_write(self.root, yaml))

    def test_bare_plugin_name_is_rejected(self):
        # `superpowers` exists in two marketplaces on this machine at
        # different versions, so a bare name names nothing in particular.
        yaml = BASE_YAML.replace("enable: []", "enable: ['superpowers']")
        with self.assertRaisesRegex(ValueError, r"<name>@<marketplace>"):
            adapters.load_adapter(_write(self.root, yaml))

    def test_duplicate_plugin_is_rejected(self):
        yaml = BASE_YAML.replace(
            "enable: []", "enable: ['sdlc@nightshift', 'sdlc@nightshift']"
        )
        with self.assertRaisesRegex(ValueError, "twice"):
            adapters.load_adapter(_write(self.root, yaml))

    def test_enable_not_a_list_is_rejected(self):
        yaml = BASE_YAML.replace("enable: []", "enable: 'sdlc@nightshift'")
        with self.assertRaisesRegex(ValueError, "not a list"):
            adapters.load_adapter(_write(self.root, yaml))


class TestAdapterPermissions(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def test_allow_entries_load(self):
        yaml = BASE_YAML + "permissions:\n  - Bash(gh:*)\n  - Bash(acli:*)\n"
        adapter = adapters.load_adapter(_write(self.root, yaml))
        self.assertEqual(adapter.permissions, ["Bash(gh:*)", "Bash(acli:*)"])

    def test_mapping_form_with_allow_key_loads(self):
        yaml = BASE_YAML + "permissions:\n  allow:\n    - Bash(uv:*)\n"
        adapter = adapters.load_adapter(_write(self.root, yaml))
        self.assertEqual(adapter.permissions, ["Bash(uv:*)"])

    def test_deny_is_not_adapter_settable(self):
        # An adapter that could write the deny list could un-deny `git push`,
        # and the bench/ branch boundary is not an approach's decision.
        yaml = BASE_YAML + "permissions:\n  deny: []\n"
        with self.assertRaisesRegex(ValueError, "unsupported `permissions:` key"):
            adapters.load_adapter(_write(self.root, yaml))


class TestVersionPinMustBeEnabled(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def test_pinning_a_disabled_plugin_is_rejected(self):
        # Otherwise the pin lands, the plugin never loads, and the row is
        # filed under a version that contributed nothing.
        yaml = BASE_YAML + (
            "version:\n  plugin: sdlc@nightshift\n  version: 0.44.0\n"
        )
        with self.assertRaisesRegex(ValueError, "does not list it in"):
            adapters.load_adapter(_write(self.root, yaml))

    def test_pinning_an_enabled_plugin_is_accepted(self):
        yaml = BASE_YAML.replace(
            "enable: []", "enable: ['sdlc@nightshift']"
        ) + "version:\n  plugin: sdlc@nightshift\n  version: 0.44.0\n"
        adapter = adapters.load_adapter(_write(self.root, yaml))
        self.assertEqual(adapter.cell_id, "demo@0.44.0")


class TestEnabledPluginsMap(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.installed = self.root / "installed_plugins.json"
        self.installed.write_text(
            json.dumps(
                {
                    "plugins": {
                        "sdlc@nightshift": [{"version": "0.45.4"}],
                        "superpowers@claude-plugins-official": [{"version": "6.2.0"}],
                        "caveman@caveman": [{"version": "1"}],
                    }
                }
            )
        )
        self.user_settings = self.root / "user-settings.json"
        self.user_settings.write_text(
            json.dumps({"enabledPlugins": {"context-mode@context-mode": True}})
        )
        self.repo = self.root / "repo"
        (self.repo / ".claude").mkdir(parents=True)
        (self.repo / ".claude" / "settings.json").write_text(
            json.dumps({"enabledPlugins": {"gtm@nightshift": True}})
        )

    def _map(self, declared):
        return environment.enabled_plugins_map(
            declared, self.repo, self.installed, self.user_settings
        )

    def test_undeclared_plugins_are_explicitly_false_not_omitted(self):
        # Omitting a key inherits the operator's setting. Only an explicit
        # false actually turns it off.
        result = self._map([])
        self.assertEqual(set(result.values()), {False})
        for key in (
            "sdlc@nightshift",
            "superpowers@claude-plugins-official",
            "caveman@caveman",
            "context-mode@context-mode",
            "gtm@nightshift",
        ):
            self.assertIn(key, result)
            self.assertFalse(result[key])

    def test_declared_plugin_is_true_and_everything_else_false(self):
        result = self._map(["sdlc@nightshift"])
        self.assertTrue(result["sdlc@nightshift"])
        self.assertFalse(result["superpowers@claude-plugins-official"])

    def test_declared_but_uninstalled_plugin_is_still_written_true(self):
        # A silent drop would report a run that measured an approach without
        # the plugin it is named after. Let Claude Code fail to find it.
        result = self._map(["ghost@nowhere"])
        self.assertTrue(result["ghost@nowhere"])

    def test_unreadable_installed_file_does_not_abort(self):
        self.installed.write_text("{ not json")
        result = self._map(["sdlc@nightshift"])
        self.assertTrue(result["sdlc@nightshift"])
        # Settings-derived keys survive; the failure mode is a narrower
        # disable list, never a crash mid-provision.
        self.assertFalse(result["gtm@nightshift"])


class TestAmbientHooks(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.user_settings = self.root / "user-settings.json"
        self.user_settings.write_text(
            json.dumps(
                {
                    "hooks": {
                        "PreToolUse": [
                            {"hooks": [{"type": "command", "command": "rtk hook claude"}]}
                        ]
                    }
                }
            )
        )
        self.repo = self.root / "repo"
        (self.repo / ".claude").mkdir(parents=True)
        (self.repo / ".claude" / "settings.json").write_text(json.dumps({}))

    def test_user_level_hooks_are_recorded(self):
        hooks = environment.ambient_hooks(self.repo, self.user_settings)
        self.assertEqual(len(hooks), 1)
        self.assertEqual(hooks[0]["event"], "PreToolUse")
        self.assertEqual(hooks[0]["command"], "rtk hook claude")

    def test_record_marks_hooks_as_a_confound_not_a_removal(self):
        record = environment.environment_record(
            [], self.repo, self.root / "missing.json", self.user_settings
        )
        self.assertEqual(len(record["ambient_hooks"]), 1)
        self.assertIn("cannot be overridden", record["note"])


class TestProvisionWritesIsolation(unittest.TestCase):
    """The settings file provision.py writes is the entire mechanism."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.worktree = self.root / "wt"
        self.worktree.mkdir()

    def test_undeclared_plugin_written_false(self):
        path = provision.write_bench_settings(
            self.worktree,
            enabled_plugins={"sdlc@nightshift": False, "opus@x": True},
            extra_allow=[],
        )
        data = json.loads(Path(path).read_text())
        self.assertFalse(data["enabledPlugins"]["sdlc@nightshift"])
        self.assertTrue(data["enabledPlugins"]["opus@x"])

    def test_adapter_permissions_are_merged_into_allow(self):
        path = provision.write_bench_settings(
            self.worktree, enabled_plugins={}, extra_allow=["Bash(acli:*)"]
        )
        data = json.loads(Path(path).read_text())
        self.assertIn("Bash(acli:*)", data["permissions"]["allow"])
        self.assertIn("Bash(git commit:*)", data["permissions"]["allow"])

    def test_adapter_cannot_weaken_the_deny_list(self):
        # Even if an adapter asks for push, deny still carries it -- Claude
        # Code resolves deny before allow, and the deny list is not
        # adapter-writable in the first place.
        path = provision.write_bench_settings(
            self.worktree, enabled_plugins={}, extra_allow=["Bash(git push:*)"]
        )
        data = json.loads(Path(path).read_text())
        self.assertIn("Bash(git push:*)", data["permissions"]["deny"])
        self.assertIn("Bash(gh pr merge:*)", data["permissions"]["deny"])

    def test_merge_allow_does_not_duplicate(self):
        merged = provision.merge_allow(["Bash(git add:*)", "Bash(uv:*)"])
        self.assertEqual(merged.count("Bash(git add:*)"), 1)
        self.assertIn("Bash(uv:*)", merged)


class TestToolCallPhaseMarkers(unittest.TestCase):
    """Frameworks run their phases through tool calls, not slash commands."""

    def test_subagent_type_is_visible_to_markers(self):
        content = [
            {
                "type": "tool_use",
                "name": "Agent",
                "input": {"subagent_type": "sdlc:solutions-architect"},
            }
        ]
        self.assertIn("solutions-architect", measure.tool_use_text(content))

    def test_file_body_is_not_dragged_in(self):
        # A Write input carries the whole file. Matching markers against it
        # would be slow and would fire on any file that merely mentions an
        # agent name.
        content = [
            {
                "type": "tool_use",
                "name": "Write",
                "input": {"file_path": "/x.md", "content": "qa-engineer " * 500},
            }
        ]
        text = measure.tool_use_text(content)
        self.assertIn("/x.md", text)
        self.assertNotIn("qa-engineer", text)

    def test_non_list_content_is_tolerated(self):
        self.assertEqual(measure.tool_use_text("just a string"), "")

    def test_marker_fires_on_a_tool_call_with_no_prose(self):
        entries = [
            {"text": "", "tool_text": "Agent sdlc:tech-lead"},
            {"text": "", "tool_text": "Agent sdlc:web-engineer"},
        ]
        phases = [
            {"id": "plan", "marker": "tech-lead"},
            {"id": "impl", "marker": "web-engineer"},
        ]
        assignment = measure.assign_phases_with_fires(entries, phases)
        self.assertEqual(
            [e["phase"] for e in assignment.entries], ["plan", "impl"]
        )
        self.assertEqual(assignment.marker_fires["impl"], 1)


class TestReportEnvironmentSection(unittest.TestCase):
    def test_lists_the_plugin_set_per_approach(self):
        runs = [
            {
                "approach": "opus",
                "environment": {"declared_plugins": [], "ambient_hooks": []},
            },
            {
                "approach": "sdlc@0.45.4",
                "environment": {
                    "declared_plugins": ["sdlc@nightshift"],
                    "ambient_hooks": [],
                },
            },
        ]
        text = "\n".join(report.render_environment(runs))
        self.assertIn("What each cell loaded", text)
        self.assertIn("*none*", text)
        self.assertIn("`sdlc@nightshift`", text)

    def test_unrecorded_runs_are_not_rendered_as_none_loaded(self):
        # "not recorded" and "none loaded" are opposite claims.
        runs = [{"approach": "legacy"}]
        text = "\n".join(report.render_environment(runs))
        self.assertIn("no environment record", text)
        self.assertIn("legacy", text)

    def test_ambient_hooks_are_surfaced(self):
        runs = [
            {
                "approach": "opus",
                "environment": {
                    "declared_plugins": [],
                    "ambient_hooks": [
                        {"event": "PreToolUse", "command": "rtk hook claude"}
                    ],
                },
            }
        ]
        text = "\n".join(report.render_environment(runs))
        self.assertIn("Hooks that ran regardless", text)
        self.assertIn("rtk hook claude", text)


class TestShippedApproachesAreValid(unittest.TestCase):
    """Every adapter in approaches/ must load, and none may inherit."""

    def test_all_load_and_declare_a_plugin_set(self):
        found = sorted(APPROACHES.glob("*.yaml"))
        self.assertTrue(found, "no approach files found")
        for path in found:
            with self.subTest(adapter=path.name):
                adapter = adapters.load_adapter(path)
                self.assertIsInstance(adapter.plugins, list)
                self.assertTrue(adapter.model)

    def test_control_arm_enables_nothing(self):
        adapter = adapters.load_adapter(APPROACHES / "opus.yaml")
        self.assertEqual(adapter.plugins, [])

    def test_plugin_approaches_pin_a_version(self):
        # An unpinned plugin row measures whatever is installed on the day.
        for name in ("sdlc-0.44.0.yaml", "sdlc-0.45.4.yaml", "superpowers.yaml"):
            with self.subTest(adapter=name):
                adapter = adapters.load_adapter(APPROACHES / name)
                self.assertIsNotNone(adapter.version)
                self.assertIn(adapter.version.plugin, adapter.plugins)

    def test_sdlc_versions_share_one_cell_namespace_but_differ(self):
        old = adapters.load_adapter(APPROACHES / "sdlc-0.44.0.yaml")
        new = adapters.load_adapter(APPROACHES / "sdlc-0.45.4.yaml")
        self.assertEqual(old.id, new.id)
        self.assertNotEqual(old.cell_id, new.cell_id)

    def test_sdlc_markers_cover_both_versions_agent_rosters(self):
        # 0.44.0 dispatches `principal-engineer` and `qa-engineer` subagents;
        # 0.45.4 deleted both and runs those playbooks inline. Markers that
        # covered only one roster would dump the other version's impl and
        # review spend into whichever phase is declared first.
        for name in ("sdlc-0.44.0.yaml", "sdlc-0.45.4.yaml"):
            with self.subTest(adapter=name):
                markers = {
                    p.id: p.marker
                    for p in adapters.load_adapter(APPROACHES / name).phases
                }
                self.assertIn("principal-engineer", markers["impl"])
                self.assertIn("web-engineer", markers["impl"])
                self.assertIn("qa-engineer", markers["review-fix"])

    def test_every_marker_is_a_valid_regex(self):
        for path in sorted(APPROACHES.glob("*.yaml")):
            adapter = adapters.load_adapter(path)
            phases = [{"id": p.id, "marker": p.marker} for p in adapter.phases]
            with self.subTest(adapter=path.name):
                # Raises ValueError naming the phase if a pattern is bad.
                measure.assign_phases_with_fires([], phases)


if __name__ == "__main__":
    unittest.main()
