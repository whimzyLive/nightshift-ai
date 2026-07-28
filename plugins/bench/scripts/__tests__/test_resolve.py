import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import resolve  # noqa: E402


class TestExtractAcs(unittest.TestCase):
    def test_pulls_acceptance_criteria_section(self):
        desc = "Objective\nDo a thing.\nAcceptance criteria\n- one\n- two\nNon-goals\n- skip"
        self.assertEqual(resolve.extract_acs(desc), "- one\n- two")

    def test_case_insensitive_heading(self):
        desc = "ACCEPTANCE CRITERIA\n- only one"
        self.assertEqual(resolve.extract_acs(desc), "- only one")

    def test_missing_section_returns_empty(self):
        self.assertEqual(resolve.extract_acs("no criteria here"), "")


class TestBuildStory(unittest.TestCase):
    def test_builds_expected_shape(self):
        fields = {
            "summary": "Do a thing",
            "description": "Acceptance criteria\n- one",
            "customfield_10016": 3,
        }
        story = resolve.build_story(fields, "NA-9", "customfield_10016")
        self.assertEqual(story["key"], "NA-9")
        self.assertEqual(story["summary"], "Do a thing")
        self.assertEqual(story["points"], 3)
        self.assertEqual(story["acs"], "- one")

    def test_missing_points_is_none_not_an_error(self):
        story = resolve.build_story({"summary": "x"}, "NA-9", "customfield_10016")
        self.assertIsNone(story["points"])


if __name__ == "__main__":
    unittest.main()
