import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PLUGIN = ROOT / "plugins" / "bench"


class TestScaffold(unittest.TestCase):
    def test_plugin_manifest_declares_name_bench(self):
        manifest = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text())
        self.assertEqual(manifest["name"], "bench")

    def test_project_json_root_matches(self):
        project = json.loads((PLUGIN / "project.json").read_text())
        self.assertEqual(project["name"], "bench")
        self.assertEqual(project["root"], "plugins/bench")

    def test_registered_in_marketplace(self):
        market = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text())
        names = [p["name"] for p in market["plugins"]]
        self.assertIn("bench", names)

    def test_registered_in_nx_release_group(self):
        nx = json.loads((ROOT / "nx.json").read_text())
        projects = nx["release"]["groups"]["plugins"]["projects"]
        self.assertIn("bench", projects)


class TestGitignoredPaths(unittest.TestCase):
    """Paths the harness writes into the real repo must never be committable."""

    def _ignored(self, relative_path):
        proc = subprocess.run(
            ["git", "-C", str(ROOT), "check-ignore", "-q", relative_path],
            capture_output=True,
        )
        return proc.returncode == 0

    def test_bench_worktrees_is_gitignored(self):
        # provision.py creates <repo>/.bench-worktrees/<cell>. If that were
        # trackable, every benchmark run would pollute the real repo's status
        # and could be committed by an approach running `git add -A`.
        self.assertIn(".bench-worktrees/", (ROOT / ".gitignore").read_text())
        self.assertTrue(self._ignored(".bench-worktrees/NA-1-opus-r1/x.txt"))

    def test_settings_local_json_is_gitignored(self):
        # provision.py writes .claude/settings.local.json into the worktree.
        # It must not be committable, or it would land in the graded diff.
        self.assertTrue(self._ignored(".claude/settings.local.json"))


if __name__ == "__main__":
    unittest.main()
