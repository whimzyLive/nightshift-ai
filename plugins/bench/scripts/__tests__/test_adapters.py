import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import adapters  # noqa: E402

YAML = """
id: demo
label: Demo Approach
setup:
  - echo setting up
run:
  prompt: |
    Implement {{ticket_key}}: {{ticket_summary}}
  flags: ["--permission-mode", "acceptEdits"]
phases:
  - {id: impl, marker: "/implement"}
teardown:
  - echo tearing down
"""


def _write(text):
    path = Path(tempfile.mkdtemp()) / "demo.yaml"
    path.write_text(text)
    return path


class TestLoadAdapter(unittest.TestCase):
    def test_loads_all_fields(self):
        adapter = adapters.load_adapter(_write(YAML))
        self.assertEqual(adapter.id, "demo")
        self.assertEqual(adapter.label, "Demo Approach")
        self.assertEqual(adapter.setup, ["echo setting up"])
        self.assertEqual(adapter.flags, ["--permission-mode", "acceptEdits"])
        self.assertEqual(adapter.teardown, ["echo tearing down"])
        self.assertIn("{{ticket_key}}", adapter.prompt)

    def test_phases_parsed(self):
        adapter = adapters.load_adapter(_write(YAML))
        self.assertEqual(len(adapter.phases), 1)
        self.assertEqual(adapter.phases[0].id, "impl")
        self.assertEqual(adapter.phases[0].marker, "/implement")

    def test_missing_phases_defaults_to_single_impl_phase(self):
        adapter = adapters.load_adapter(_write("id: bare\nlabel: Bare\nrun:\n  prompt: hi\n"))
        self.assertEqual([p.id for p in adapter.phases], ["impl"])
        self.assertEqual(adapter.phases[0].marker, "")

    def test_missing_prompt_is_an_error(self):
        with self.assertRaises(ValueError):
            adapters.load_adapter(_write("id: bad\nlabel: Bad\n"))

    def test_non_dict_yaml_document_is_an_error(self):
        # Finding 1: bare list raises descriptive ValueError, not AttributeError
        with self.assertRaisesRegex(ValueError, "must be a YAML mapping"):
            adapters.load_adapter(_write("- a\n- b\n"))

    def test_phase_entry_missing_id_is_an_error(self):
        # Finding 2: phase without id raises descriptive ValueError, not KeyError
        with self.assertRaisesRegex(ValueError, "phase 0 missing required key 'id'"):
            adapters.load_adapter(_write("id: bad\nrun:\n  prompt: hi\nphases:\n  - {marker: x}\n"))


class TestRender(unittest.TestCase):
    def test_substitutes_known_variables(self):
        out = adapters.render("do {{ticket_key}} now", {"ticket_key": "NA-1"})
        self.assertEqual(out, "do NA-1 now")

    def test_unknown_variable_is_an_error(self):
        with self.assertRaises(ValueError):
            adapters.render("{{not_a_var}}", {"ticket_key": "NA-1"})

    def test_does_not_evaluate_shell(self):
        out = adapters.render("{{ticket_summary}}", {"ticket_summary": "$(rm -rf /)"})
        self.assertEqual(out, "$(rm -rf /)")

    def test_allowed_variable_absent_from_dict_is_an_error(self):
        # Finding 3: allowed var missing from variables dict raises ValueError
        with self.assertRaisesRegex(ValueError, "adapter variable ticket_key not provided"):
            adapters.render("{{ticket_key}}", {})

    def test_allowed_variable_present_but_empty_renders_empty(self):
        # Finding 3 corollary: a key present with empty-string value is legitimate
        out = adapters.render("result: {{ticket_summary}}", {"ticket_summary": ""})
        self.assertEqual(out, "result: ")


class TestShippedAdapters(unittest.TestCase):
    def test_opus_adapter_loads_and_has_no_setup(self):
        root = Path(__file__).resolve().parents[2]
        adapter = adapters.load_adapter(root / "approaches" / "opus.yaml")
        self.assertEqual(adapter.id, "opus")
        self.assertEqual(adapter.setup, [])
        self.assertEqual([p.id for p in adapter.phases], ["impl"])


if __name__ == "__main__":
    unittest.main()
