"""Pre-made twin tickets: validation, and why each check exists.

The operator creates twins by hand because acli 1.3.22 cannot set story points
by any route -- no `--custom` flag, `--from-json` rejects
`additionalAttributes` as an unknown field, and `clone` copies summary,
description, labels and type but leaves points unset. All three tested against
a live site.

Hand-made means hand-mistakeable. Every check below has a specific wrong answer
it prevents, and the test names say which.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import provision  # noqa: E402
from benchlib import acli, adapters  # noqa: E402

APPROACHES = Path(__file__).resolve().parents[2] / "approaches"
POINTS_FIELD = "customfield_10016"

ACS = "- criterion one\n- criterion two\n"
SOURCE = {"key": "NA-82", "summary": "Blogs", "description": "d", "acs": ACS, "points": 8}


def _fields(points=8, labels=("bench-run",), acs=ACS, summary="[bench] Blogs"):
    return {
        "summary": summary,
        "description": "As a user\n\nAcceptance Criteria\n\n" + acs,
        "labels": list(labels),
        "issuetype": {"name": "Story"},
        POINTS_FIELD: points,
    }


class TestTwinValidation(unittest.TestCase):
    def _validate(self, fields, twin_key="NA-90", source=None):
        with mock.patch.object(acli, "fetch_issue", return_value=fields):
            return provision.validate_twin(twin_key, source or SOURCE, POINTS_FIELD)

    def test_a_good_twin_passes_and_returns_its_story(self):
        twin = self._validate(_fields())
        self.assertEqual(twin["key"], "NA-90")
        self.assertEqual(twin["points"], 8)

    def test_unpointed_twin_is_refused(self):
        # THE reason twins exist. /sdlc:auto triages on points, so this cell
        # would run the lightweight path while its row claims the full one.
        with self.assertRaisesRegex(provision.TwinTicketError, "no story points"):
            self._validate(_fields(points=None))

    def test_the_error_names_the_source_points_so_you_know_what_to_set(self):
        with self.assertRaises(provision.TwinTicketError) as ctx:
            self._validate(_fields(points=None))
        self.assertIn("has 8", str(ctx.exception).replace("(the source ticket ", "("))

    def test_unlabelled_twin_is_refused(self):
        # Cleanup finds twins by label. Unlabelled, its story branch survives
        # cleanup and the next run reuses that branch instead of starting fresh.
        with self.assertRaisesRegex(provision.TwinTicketError, "bench-run"):
            self._validate(_fields(labels=()))

    def test_drifted_acceptance_criteria_are_refused(self):
        # Graders score the diff against the SOURCE's criteria, so a drifted
        # twin has the session implement one spec and be marked against another.
        with self.assertRaisesRegex(provision.TwinTicketError, "acceptance criteria"):
            self._validate(_fields(acs="- criterion one\n- something else\n"))

    def test_extra_criterion_is_refused(self):
        with self.assertRaises(provision.TwinTicketError):
            self._validate(_fields(acs=ACS + "- criterion three\n"))

    def test_whitespace_and_bullet_style_differences_are_tolerated(self):
        # A twin retyped by hand differs cosmetically; that is not drift.
        twin = self._validate(_fields(acs="*  criterion one \n*   criterion   two\n"))
        self.assertEqual(twin["points"], 8)

    def test_using_the_source_ticket_itself_is_refused(self):
        # The lifecycle writes comments, transitions and a PR to whatever key it
        # is given.
        with self.assertRaisesRegex(provision.TwinTicketError, "source ticket itself"):
            self._validate(_fields(), twin_key="NA-82")

    def test_a_missing_twin_points_at_auth_not_at_the_ticket(self):
        # A wrong-site acli reports "issue does not exist", which sends the
        # reader after the ticket instead of the auth. Cost real time once.
        with mock.patch.object(
            acli, "fetch_issue", side_effect=acli.AcliError("Issue does not exist")
        ):
            with self.assertRaises(provision.TwinTicketError) as ctx:
                provision.validate_twin("NA-90", SOURCE, POINTS_FIELD)
        self.assertIn("acli jira auth status", str(ctx.exception))


class TestAdapterContract(unittest.TestCase):
    def test_sdlc_adapters_require_a_dedicated_ticket(self):
        for name in ("sdlc-0.44.0.yaml", "sdlc-0.45.4.yaml"):
            with self.subTest(adapter=name):
                self.assertTrue(
                    adapters.load_adapter(APPROACHES / name).dedicated_ticket
                )

    def test_read_only_approaches_do_not(self):
        for name in ("opus.yaml", "superpowers.yaml", "speckit.yaml"):
            with self.subTest(adapter=name):
                self.assertFalse(
                    adapters.load_adapter(APPROACHES / name).dedicated_ticket
                )

    def test_the_old_key_fails_loudly_rather_than_being_ignored(self):
        # `scratch_ticket` meant "clone one for me", which the harness no longer
        # does. Silently ignoring it would provision a cell with no ticket.
        root = Path(tempfile.mkdtemp())
        path = root / "a.yaml"
        path.write_text(
            "id: x\nplugins:\n  enable: []\nscratch_ticket: true\n"
            "run:\n  model: claude-opus-5\n  prompt: hi\n"
        )
        with self.assertRaisesRegex(ValueError, "no longer exists"):
            adapters.load_adapter(path)


class TestCleanupKeepsTwinsButNotTheirBranches(unittest.TestCase):
    """A twin survives; its story branch must not.

    The SDLC playbook reuses an existing `feat/<KEY>` branch rather than
    duplicating it, so a leftover branch makes the next run on that twin check
    out the previous run's finished work -- the collision twins exist to avoid,
    reintroduced by not cleaning up.
    """

    def setUp(self):
        import subprocess
        import cleanup
        self.cleanup = cleanup
        self.root = Path(tempfile.mkdtemp())
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
               "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
               "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(
            ["git", "-C", str(self.root), "commit", "-q", "--allow-empty", "-m", "x"],
            check=True, env=env)
        for b in ("bench/NA-82/sdlc@0.45.4/r1", "feat/NA-90", "fix/NA-91", "feat/NA-999"):
            subprocess.run(["git", "-C", str(self.root), "branch", b], check=True)

    def test_twin_story_branches_are_found(self):
        found = self.cleanup.twin_branches(self.root, ["NA-90", "NA-91"])
        self.assertIn("feat/NA-90", found)
        self.assertIn("fix/NA-91", found)

    def test_an_unrelated_story_branch_is_not_touched(self):
        found = self.cleanup.twin_branches(self.root, ["NA-90"])
        self.assertNotIn("feat/NA-999", found)

    def test_plan_includes_both_bench_and_twin_branches(self):
        with mock.patch.object(self.cleanup, "twin_issues", return_value=["NA-90"]):
            with mock.patch.object(self.cleanup, "draft_prs", return_value=[]):
                data = self.cleanup.plan(self.root, "NA-82", "NA")
        self.assertIn("bench/NA-82/sdlc@0.45.4/r1", data["branches"])
        self.assertIn("feat/NA-90", data["branches"])

    def test_execute_keeps_the_twin_issue(self):
        data = {"pull_requests": [], "worktrees": [], "branches": [],
                "twin_issues": ["NA-90"]}
        with mock.patch.object(acli, "delete_issue") as killer:
            log = self.cleanup.execute(self.root, data)
        killer.assert_not_called()
        self.assertTrue(any("kept twin issue NA-90" in line for line in log))

    def test_render_says_twins_are_kept(self):
        text = self.cleanup.render_plan(
            {"ticket": "NA-82", "branches": [], "worktrees": [],
             "twin_issues": ["NA-90"], "pull_requests": []}
        )
        self.assertIn("KEPT", text)


if __name__ == "__main__":
    unittest.main()


class TestEmptyAcsGetTheirOwnDiagnosis(unittest.TestCase):
    """Zero criteria extracted is a different problem from drifted criteria.

    A cloned issue built from FLATTENED text arrives as one paragraph. The text
    plainly says "Acceptance Criteria" to a human, but extraction looks for a
    heading NODE, so nothing is found. That happened to NA-84 and cost a
    debugging round: the operator had a ticket that looked correct and a message
    that only said the criteria differed.
    """

    def test_zero_extracted_explains_the_flat_paragraph_cause(self):
        flat = {
            "summary": "[bench] Blogs",
            # Everything in one blob: no heading, no list.
            "description": "As a user I want blogs. Acceptance Criteria - one - two",
            "labels": ["bench-run"],
            "issuetype": {"name": "Story"},
            POINTS_FIELD: 8,
        }
        with mock.patch.object(acli, "fetch_issue", return_value=flat):
            with self.assertRaises(provision.TwinTicketError) as ctx:
                provision.validate_twin("NA-84", SOURCE, POINTS_FIELD)
        msg = str(ctx.exception)
        self.assertIn("single flat paragraph", msg)
        self.assertIn("--description-file", msg)

    def test_drifted_but_present_acs_get_no_flat_paragraph_hint(self):
        # Wrong advice is worse than none: this ticket's structure is fine.
        with mock.patch.object(
            acli, "fetch_issue", return_value=_fields(acs="- one\n- different\n")
        ):
            with self.assertRaises(provision.TwinTicketError) as ctx:
                provision.validate_twin("NA-90", SOURCE, POINTS_FIELD)
        self.assertNotIn("flat paragraph", str(ctx.exception))
