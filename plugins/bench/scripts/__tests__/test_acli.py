import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import acli  # noqa: E402


class TestSeekJson(unittest.TestCase):
    def test_decodes_plain_json(self):
        self.assertEqual(acli.seek_json('{"a": 1}'), {"a": 1})

    def test_skips_leading_banner(self):
        raw = 'Authenticated site: example.atlassian.net\n{"a": 1}'
        self.assertEqual(acli.seek_json(raw), {"a": 1})

    def test_decodes_leading_array(self):
        self.assertEqual(acli.seek_json("banner\n[1, 2]"), [1, 2])

    def test_raises_when_no_json_present(self):
        with self.assertRaises(ValueError):
            acli.seek_json("✗ Error: field not allowed")


class TestFieldExtraction(unittest.TestCase):
    def test_summary(self):
        self.assertEqual(acli.issue_summary({"summary": "Do a thing"}), "Do a thing")

    def test_story_points_reads_configured_field(self):
        fields = {"customfield_10016": 5}
        self.assertEqual(acli.story_points(fields, "customfield_10016"), 5)

    def test_story_points_missing_returns_none(self):
        self.assertIsNone(acli.story_points({}, "customfield_10016"))

    def test_description_flattens_adf(self):
        adf = {
            "type": "doc",
            "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Hello"}]},
                {"type": "paragraph", "content": [{"type": "text", "text": "World"}]},
            ],
        }
        self.assertEqual(acli.issue_description({"description": adf}), "Hello\n\nWorld")

    def test_description_passes_through_plain_string(self):
        self.assertEqual(acli.issue_description({"description": "plain"}), "plain")

    def test_description_missing_returns_empty(self):
        self.assertEqual(acli.issue_description({}), "")

    def test_description_hardbreak_inside_paragraph(self):
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "paragraph",
                    "content": [
                        {"type": "text", "text": "Line 1"},
                        {"type": "hardBreak"},
                        {"type": "text", "text": "Line 2"},
                    ],
                },
            ],
        }
        result = acli.issue_description({"description": adf})
        # Should not concatenate into "Line 1Line 2"
        self.assertIn("Line 1\nLine 2", result)

    def test_description_codeblock_separated(self):
        adf = {
            "type": "doc",
            "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Before"}]},
                {
                    "type": "codeBlock",
                    "content": [{"type": "text", "text": "code"}],
                },
                {"type": "paragraph", "content": [{"type": "text", "text": "After"}]},
            ],
        }
        result = acli.issue_description({"description": adf})
        # Should not concatenate: "Beforecode" or "codeAfter"
        self.assertNotIn("Beforecode", result)
        self.assertNotIn("codeAfter", result)

    def test_description_bullet_list_items_separated(self):
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Item 1"}],
                                }
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Item 2"}],
                                }
                            ],
                        },
                    ],
                },
            ],
        }
        result = acli.issue_description({"description": adf})
        # Should not concatenate: "Item 1Item 2"
        self.assertNotIn("Item 1Item 2", result)
        # Should have markers
        self.assertIn("- Item 1", result)
        self.assertIn("- Item 2", result)

    def test_description_nested_bullet_list(self):
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "bulletList",
                    "content": [
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Item 1"}],
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
                                                        {"type": "text", "text": "Nested"}
                                                    ],
                                                }
                                            ],
                                        },
                                    ],
                                },
                            ],
                        },
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Item 2"}],
                                }
                            ],
                        },
                    ],
                },
            ],
        }
        result = acli.issue_description({"description": adf})
        # Nested item should be indented differently from siblings
        self.assertIn("- Item 1", result)
        self.assertIn("  - Nested", result)
        self.assertIn("- Item 2", result)


if __name__ == "__main__":
    unittest.main()
