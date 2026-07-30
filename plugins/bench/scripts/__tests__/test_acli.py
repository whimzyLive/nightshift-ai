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

    def test_description_flat_bullet_list_exact_output(self):
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
                        {
                            "type": "listItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Item 3"}],
                                }
                            ],
                        },
                    ],
                },
            ],
        }
        result = acli.issue_description({"description": adf})
        expected = "- Item 1\n\n\n- Item 2\n\n\n- Item 3"
        self.assertEqual(result, expected)

    def test_description_nested_bullet_list_exact_output(self):
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
        expected = "- Item 1\n\n  - Nested\n\n\n\n\n\n- Item 2"
        self.assertEqual(result, expected)

    def test_description_task_list_items_separated(self):
        adf = {
            "type": "doc",
            "content": [
                {
                    "type": "taskList",
                    "content": [
                        {
                            "type": "taskItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Task 1"}],
                                }
                            ],
                        },
                        {
                            "type": "taskItem",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "content": [{"type": "text", "text": "Task 2"}],
                                }
                            ],
                        },
                    ],
                },
            ],
        }
        result = acli.issue_description({"description": adf})
        # Should not concatenate: "Task 1Task 2"
        self.assertNotIn("Task 1Task 2", result)
        # Should have markers
        self.assertIn("- Task 1", result)
        self.assertIn("- Task 2", result)


if __name__ == "__main__":
    unittest.main()


class TestWriteOpsPassKeysAsFlags(unittest.TestCase):
    """acli takes its targets by flag, not positionally, on the write verbs.

    Two live failures came from getting this wrong, both silent until the call
    ran against a real site:

      acli jira workitem delete NA-83 --yes
        -> "at least one of the flags in the group [key from-file jql filter]
            is required" -- the bare key is ignored entirely.

      acli jira workitem comment create NA-83 --body ...
        -> same shape.

    `view` is the exception: its usage really is `view [key] [flags]`. So this
    cannot be a blanket rule, which is exactly why it needs a test per verb
    rather than a convention.
    """

    def setUp(self):
        self.calls = []
        self._real_run = acli.run

        def fake_run(args):
            self.calls.append(list(args))
            return '{"key": "NA-999", "issues": []}'

        acli.run = fake_run

    def tearDown(self):
        acli.run = self._real_run

    def test_delete_passes_key_as_a_flag(self):
        acli.delete_issue("NA-83")
        self.assertEqual(
            self.calls[0], ["jira", "workitem", "delete", "--key", "NA-83", "--yes"]
        )

    def test_delete_takes_one_key_per_call(self):
        # --key accepts a list, but a partial failure across a batch gives no
        # way to tell which issues died. This is the irreversible operation.
        acli.delete_issue("NA-83")
        key_index = self.calls[0].index("--key")
        self.assertNotIn(",", self.calls[0][key_index + 1])

    def test_comment_passes_key_as_a_flag(self):
        acli.comment("NA-83", "hello")
        self.assertIn("--key", self.calls[0])
        self.assertEqual(self.calls[0][self.calls[0].index("--key") + 1], "NA-83")

    def test_search_uses_jql(self):
        acli.search_by_label("NA")
        self.assertIn("--jql", self.calls[0])

    def test_create_names_project_type_and_summary_by_flag(self):
        acli.create_issue("NA", "s", "d", "Story")
        argv = self.calls[0]
        for flag in ("--project", "--type", "--summary", "--description", "--label"):
            self.assertIn(flag, argv)

    def test_create_always_applies_the_bench_label(self):
        # Cleanup finds scratch issues by this label. An issue created without
        # it is undiscoverable and will never be cleaned up.
        acli.create_issue("NA", "s", "d", "Story", labels=["other"])
        argv = self.calls[0]
        self.assertIn(acli.BENCH_LABEL, argv[argv.index("--label") + 1])

    def test_view_still_uses_a_positional_key(self):
        # `acli jira workitem view [key] [flags]` -- do not "fix" this one.
        acli.fetch_issue("NA-82")
        self.assertEqual(self.calls[0][:4], ["jira", "workitem", "view", "NA-82"])
