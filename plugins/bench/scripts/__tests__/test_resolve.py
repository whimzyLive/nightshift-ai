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


class TestExtractAcsStructural(unittest.TestCase):
    def test_na68_mimic_with_tasklist(self):
        """NA-68 mimic: level-3 heading, taskList, terminated by level-3 'Out of Scope'."""
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 3},
                    "content": [{"type": "text", "text": "Acceptance Criteria"}],
                },
                {
                    "type": "taskList",
                    "content": [
                        {
                            "type": "taskItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {
                                            "type": "text",
                                            "text": "First criterion",
                                        }
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "taskItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {
                                            "type": "text",
                                            "text": "Second criterion",
                                        }
                                    ],
                                }
                            ],
                        },
                    ],
                },
                {
                    "type": "heading",
                    "attrs": {"level": 3},
                    "content": [{"type": "text", "text": "Out of Scope"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Do not include"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
            ],
        }
        acs = resolve.extract_acs_structural(adf)
        # Should contain criteria, not "Out of Scope" text
        self.assertIn("First criterion", acs)
        self.assertIn("Second criterion", acs)
        self.assertNotIn("Out of Scope", acs)
        self.assertNotIn("Do not include", acs)

    def test_na80_mimic_with_bulletlist(self):
        """NA-80 mimic: level-2 heading, bulletList criteria, terminated by 'Non-goals'."""
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Acceptance criteria"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 1"}
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 2"}
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 3"}
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 4"}
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 5"}
                                    ],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Criterion 6"}
                                    ],
                                }
                            ],
                        },
                    ],
                },
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Non-goals"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Skip this"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
            ],
        }
        acs = resolve.extract_acs_structural(adf)
        # Should contain all 6 criteria
        for i in range(1, 7):
            self.assertIn(f"Criterion {i}", acs)
        # Should not contain non-goals section
        self.assertNotIn("Non-goals", acs)
        self.assertNotIn("Skip this", acs)

    def test_unknown_section_heading_terminates_correctly(self):
        """Unknown section heading like 'Rollout plan' should still terminate."""
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Acceptance Criteria"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Do this"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Rollout plan"}],
                },
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": "Skip this section"}],
                },
            ],
        }
        acs = resolve.extract_acs_structural(adf)
        self.assertIn("Do this", acs)
        self.assertNotIn("Rollout plan", acs)
        self.assertNotIn("Skip this section", acs)

    def test_criteria_as_last_section_captures_to_end(self):
        """When AC is the last section, should capture to end without crashing."""
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Objective"}],
                },
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": "Some objective"}],
                },
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Acceptance Criteria"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Final criterion"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
            ],
        }
        acs = resolve.extract_acs_structural(adf)
        self.assertIn("Final criterion", acs)
        self.assertNotIn("Objective", acs)
        self.assertNotIn("Some objective", acs)

    def test_returns_empty_if_no_ac_heading(self):
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 2},
                    "content": [{"type": "text", "text": "Objective"}],
                },
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": "No criteria here"}],
                },
            ],
        }
        acs = resolve.extract_acs_structural(adf)
        self.assertEqual(acs, "")


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

    def test_uses_structural_extraction_for_adf(self):
        """When description is ADF dict, should use structural extraction."""
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "heading",
                    "attrs": {"level": 3},
                    "content": [{"type": "text", "text": "Acceptance Criteria"}],
                },
                {
                    "type": "taskList",
                    "content": [
                        {
                            "type": "taskItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "ADF criterion"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
                {
                    "type": "heading",
                    "attrs": {"level": 3},
                    "content": [{"type": "text", "text": "Out of Scope"}],
                },
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [
                                        {"type": "text", "text": "Skip"}
                                    ],
                                }
                            ],
                        }
                    ],
                },
            ],
        }
        fields = {
            "summary": "Test",
            "description": adf,
            "customfield_10016": 1,
        }
        story = resolve.build_story(fields, "NA-X", "customfield_10016")
        # Should use structural extraction
        self.assertIn("ADF criterion", story["acs"])
        self.assertNotIn("Out of Scope", story["acs"])
        self.assertNotIn("Skip", story["acs"])


if __name__ == "__main__":
    unittest.main()
