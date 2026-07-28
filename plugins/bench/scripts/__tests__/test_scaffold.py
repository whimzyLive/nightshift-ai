import json
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


if __name__ == "__main__":
    unittest.main()
