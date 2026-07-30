#!/usr/bin/env python3
"""Provision an isolated worktree for one benchmark cell.

Runs execute against the real repository, so the branch-prefix guard here is a
safety boundary, not a naming convention. Nothing in this plugin may write a ref
outside bench/.

Usage:
  python3 provision.py --story story.json --approach opus --run-id r1 \
      --repo /path/to/repo --out cell.json
"""
import argparse
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import resolve  # noqa: E402
from benchlib import acli, adapters, config, environment, plugins  # noqa: E402

BENCH_PREFIX = "bench/"


class UnsafeBranchError(RuntimeError):
    pass


def cell_id(approach: str, version: Optional[str]) -> str:
    """The identity this cell is filed under.

    A version-pinned cell must not share an identity with the same approach
    at a different version: `artifacts` below carries no run_id, so two
    versions under one id would have the second overwrite the first's test
    evidence, and the report would show two rows it cannot tell apart.

    Mirrors adapters.Adapter.cell_id; execute.py asserts the two agree.
    """
    if not version:
        return approach
    return "{0}@{1}".format(approach, version)


def branch_name(ticket: str, approach: str, run_id: str) -> str:
    return f"{BENCH_PREFIX}{ticket}/{approach}/{run_id}"


def assert_bench_branch(name: str) -> None:
    """Validate that a branch name is safe and under the bench/ namespace.

    This is a security boundary: it must be impossible for a caller to talk
    this function into approving a branch outside bench/.
    """
    # Prefix check: must be under bench/
    if not name.startswith(BENCH_PREFIX):
        raise UnsafeBranchError(f"refusing to operate on non-bench branch: {name}")

    # Traversal check: no ".." segments
    if ".." in name:
        raise UnsafeBranchError(f"refusing traversal in branch name: {name}")

    # Whitespace and control character checks
    for char in name:
        if char in (" ", "\t", "\n", "\r") or ord(char) < 32:
            raise UnsafeBranchError(
                f"refusing whitespace or control character in branch name: {name}"
            )

    # Leading/trailing whitespace (redundant with above, but explicit)
    if name != name.strip():
        raise UnsafeBranchError(f"refusing leading/trailing whitespace in branch name: {name}")

    # Dangerous characters check
    dangerous_chars = set(":?*[\\~^")
    for char in dangerous_chars:
        if char in name:
            raise UnsafeBranchError(f"refusing dangerous character '{char}' in branch name: {name}")

    # Non-ASCII check (our branch names are always ASCII)
    try:
        name.encode("ascii")
    except UnicodeEncodeError:
        raise UnsafeBranchError(f"refusing non-ASCII characters in branch name: {name}")

    # Consecutive slashes check
    if "//" in name:
        raise UnsafeBranchError(f"refusing consecutive slashes in branch name: {name}")

    # /./ or /../ segment checks
    if "/./" in name:
        raise UnsafeBranchError(f"refusing /./ segment in branch name: {name}")
    if "/../" in name:
        raise UnsafeBranchError(f"refusing /../ segment in branch name: {name}")

    # Leading or trailing slash check
    if name.startswith("/") or name.endswith("/"):
        raise UnsafeBranchError(f"refusing leading or trailing slash in branch name: {name}")

    # Trailing .lock check
    if name.endswith(".lock"):
        raise UnsafeBranchError(f"refusing .lock suffix in branch name: {name}")

    # Final authority: git check-ref-format
    proc = subprocess.run(
        ["git", "check-ref-format", "--branch", name],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise UnsafeBranchError(
            f"git check-ref-format rejected branch name: {name}\n{proc.stderr.strip()}"
        )


# Permissions a benchmark run needs to be able to happen at all.
#
# The worktree is a fresh checkout: it carries the repo's committed
# .claude/settings.json (empty allow list) and NOT .claude/settings.local.json,
# which is gitignored. The adapters pass --permission-mode acceptEdits, which
# auto-approves EDITS ONLY -- not Bash. So a session told to "commit your
# changes" and "run the test suite" could do neither: no commit means
# `git diff base_sha..HEAD` is empty, work_done is all zeros, and the graders
# grade nothing.
#
# Every entry below is harness friction, not part of the approach being
# measured. An approach is not being judged on whether it can get past a
# permission prompt in a non-interactive session; it is being judged on the
# code it produces. Granting these makes the measurement possible; it does
# not advantage any approach over another, because every approach gets the
# same grant.
#
# Deliberately NOT granted: anything that could push, merge, or touch a ref
# outside the worktree. The bench branch-prefix guarantee is a hard boundary
# and no convenience justifies weakening it.
BENCH_PERMISSIONS = [
    "Bash(git add:*)",
    "Bash(git commit:*)",
    "Bash(git status:*)",
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(git show:*)",
    "Bash(git rev-parse:*)",
    "Bash(git checkout:*)",
    "Bash(git restore:*)",
    "Bash(git stash:*)",
    "Bash(npm:*)",
    "Bash(npx:*)",
    "Bash(pnpm:*)",
    "Bash(yarn:*)",
    "Bash(node:*)",
    "Bash(python3:*)",
    "Bash(pytest:*)",
    "Bash(make:*)",
    "Bash(cargo:*)",
    "Bash(go:*)",
    "Bash(mkdir:*)",
    "Bash(ls:*)",
    "Bash(cat:*)",
    "Bash(rg:*)",
    "Bash(grep:*)",
    "Bash(find:*)",
]

# `git push` is deliberately ABSENT here. It moved to the PreToolUse guard
# (scripts/bench_guard.py), which allows pushes to this cell's own refs and
# denies everything else -- because a blanket deny measures a blocked session
# rather than an approach, and the SDLC lifecycle ends at a pull request.
#
# The rest stay as a blunt deny as well as being checked by the guard. Deny
# rules resolve before allow and before any hook, so these hold even if the
# hook fails to load, and the guard's parser is never the only thing standing
# between a run and a merge.
BENCH_DENIED_PERMISSIONS = [
    "Bash(git merge:*)",
    "Bash(git rebase:*)",
    "Bash(gh pr merge:*)",
    "Bash(gh pr ready:*)",
    "Bash(git push --force:*)",
    "Bash(git push -f:*)",
]

GUARD_CONFIG_NAME = "bench-guard.json"

GUARD_RATIONALE = (
    "Read by plugins/bench/scripts/bench_guard.py, registered as this "
    "worktree's PreToolUse hook. `allowed_refs` are anchored regexes: a push "
    "whose destination matches none of them is denied with a reason the model "
    "sees. main/master/develop are refused regardless of what this file says. "
    "The hook fails closed -- if this file is missing or malformed, every "
    "guarded verb is denied rather than allowed."
)


def allowed_refs(ticket: str, branch: str) -> list:
    """The refs this cell may write.

    Three entries, each earning its place:

    * the cell's own bench branch -- what provisioning created;
    * `bench/**` -- an approach may legitimately branch again beneath it;
    * `feat/<TICKET>` and `fix/<TICKET>` for THIS cell's ticket only -- the
      SDLC plugin derives its story branch from the ticket key and cannot be
      told otherwise.

    The ticket key is the per-cell scratch issue, not the source ticket, which
    is what keeps two cells of the same source story from writing the same
    `feat/` ref and reusing each other's branch.
    """
    return [
        re.escape(branch),
        r"bench/[^\s]+",
        r"(feat|fix)/{0}(-[A-Za-z0-9._-]+)?".format(re.escape(ticket)),
    ]


def write_guard_config(worktree: Path, ticket: str, branch: str, cell: str) -> Path:
    settings_dir = worktree / ".claude"
    settings_dir.mkdir(parents=True, exist_ok=True)
    target = settings_dir / GUARD_CONFIG_NAME
    target.write_text(
        json.dumps(
            {
                "_comment": GUARD_RATIONALE,
                "ticket": ticket,
                "cell": cell,
                "branch": branch,
                "allowed_refs": allowed_refs(ticket, branch),
                # Same rules, phrased for the deny message the model reads.
                "allowed_refs_human": [
                    branch,
                    "anything under bench/",
                    "feat/{0} or fix/{0}".format(ticket),
                ],
            },
            indent=2,
        )
        + "\n"
    )
    return target


def guard_hook_block(guard_script: Path) -> dict:
    return {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        # Both halves quoted: the interpreter path and the
                        # script path can each contain spaces, and this string
                        # is executed by a shell.
                        "command": "{0} {1}".format(
                            shlex.quote(sys.executable), shlex.quote(str(guard_script))
                        ),
                    }
                ],
            }
        ]
    }

PLUGIN_RATIONALE = (
    "enabledPlugins is written EXHAUSTIVELY -- true for the adapter's declared "
    "plugin set, false for every other plugin this machine knows about. This "
    "file overrides both the repository's committed .claude/settings.json and "
    "the operator's ~/.claude/settings.json, which is the only reason the "
    "measurement means anything: a bench worktree is a checkout of the subject "
    "repo, so without this an approach labelled 'no framework' would run with "
    "whatever plugins the operator happens to have enabled. Hooks declared in "
    "those two settings files cannot be overridden from here; they are recorded "
    "in the run as ambient_hooks instead."
)

SETTINGS_RATIONALE = (
    "Written by plugins/bench/scripts/provision.py for a benchmark cell. "
    "The worktree is a fresh checkout that carries the committed "
    ".claude/settings.json (empty allow list) but NOT the gitignored "
    ".claude/settings.local.json, and the adapters run with "
    "--permission-mode acceptEdits, which auto-approves edits but NOT Bash. "
    "Without this file a session told to commit its work and run the tests "
    "can do neither, the graded diff is empty, and the cell reports a clean "
    "0 findings against no code. These grants remove harness friction that "
    "is not part of the approach being measured -- every approach gets the "
    "same grant. Push, merge, rebase and PR-merge stay denied: the bench/ "
    "branch boundary is not negotiable."
)


def merge_allow(extra: list) -> list:
    """Harness permissions plus the adapter's own, order-stable, deduplicated.

    Adapter entries cannot weaken anything: Claude Code resolves deny before
    allow, so an adapter that asked for `Bash(git push:*)` would still be
    denied it. The adapter list widens what an approach can do to perform its
    own behaviour; it does not touch the boundary.
    """
    merged = list(BENCH_PERMISSIONS)
    for entry in extra:
        if entry not in merged:
            merged.append(entry)
    return merged


def write_bench_settings(
    worktree: Path,
    enabled_plugins: Optional[dict] = None,
    extra_allow: Optional[list] = None,
    guard_script: Optional[Path] = None,
) -> Path:
    """Write .claude/settings.local.json into a benchmark worktree.

    Provisioning owns this, not execute.py: the file is a property of the
    WORKTREE, created in the same step that creates the worktree, so the
    worktree is never in a state where it exists but cannot be worked in.
    It also keeps the measured window clean -- execute.py's timer starts at
    the session, and writing permissions is setup, not measured work.

    `enabled_plugins` is the exhaustive true/false map from
    benchlib.environment. Passing None writes no plugin control at all, which
    means the cell inherits the operator's enabled plugins -- only correct for
    callers that are not measuring anything.
    """
    settings_dir = worktree / ".claude"
    settings_dir.mkdir(parents=True, exist_ok=True)
    target = settings_dir / "settings.local.json"
    payload = {
        "_comment": SETTINGS_RATIONALE,
        "permissions": {
            "allow": merge_allow(extra_allow or []),
            "deny": BENCH_DENIED_PERMISSIONS,
        },
    }
    if enabled_plugins is not None:
        payload["_plugins_comment"] = PLUGIN_RATIONALE
        payload["enabledPlugins"] = enabled_plugins
    if guard_script is not None:
        payload["hooks"] = guard_hook_block(guard_script)
    target.write_text(json.dumps(payload, indent=2) + "\n")
    return target


class TwinTicketError(RuntimeError):
    """The dedicated ticket for this cell is missing or unusable.

    Raised BEFORE the worktree exists and before anything is spent. Every
    condition here produced, or would have produced, a cell whose numbers look
    real and describe something other than what the row claims.
    """


def validate_twin(twin_key: str, source: dict, points_field: str) -> dict:
    """Check a hand-made twin ticket is actually usable, and return its story.

    The operator creates twins by hand because acli cannot set story points --
    verified three ways on acli 1.3.22: no `--custom` flag, `--from-json` with
    `additionalAttributes` rejected as an unknown field, and `clone` copies
    summary, description, labels and type but leaves points unset.

    Hand-made means hand-mistakeable, so each check below exists because
    skipping it yields a plausible-looking wrong answer:

    * **Exists** -- otherwise the session runs `/sdlc:auto` against a key Jira
      does not have and burns a cell discovering that.
    * **Points set** -- the entire reason twins exist. `/sdlc:auto` triages on
      points, so an unpointed twin takes the lightweight path while the report
      labels the row the full lifecycle.
    * **Carries the bench label** -- cleanup finds twins by label. An unlabelled
      twin is invisible to it, and its leftover branch collides with the next
      run on the same twin.
    * **Same acceptance criteria as the source** -- graders score the diff
      against the SOURCE story's ACs. A twin whose ACs drifted has the session
      implement one spec and be marked against another.
    * **Not the source itself** -- running the lifecycle on the source ticket
      writes benchmark noise onto real work.
    """
    if twin_key == source["key"]:
        raise TwinTicketError(
            "--twin-ticket is {0}, which is the source ticket itself. The "
            "lifecycle writes comments, transitions and a PR to whatever key it "
            "is given; point it at a dedicated twin.".format(twin_key)
        )

    try:
        fields = acli.fetch_issue(twin_key)
    except acli.AcliError as exc:
        raise TwinTicketError(
            "cannot read twin ticket {0}: {1}\nIf this says the issue does not "
            "exist, check `acli jira auth status` names the configured Jira "
            "site before concluding the ticket is missing.".format(twin_key, exc)
        )

    twin = resolve.build_story(fields, twin_key, points_field)

    if twin["points"] is None:
        raise TwinTicketError(
            "twin ticket {0} has no story points. That is the one thing a twin "
            "exists to carry: /sdlc:auto triages on points, so this cell would "
            "run the lightweight path while its row claims the full lifecycle. "
            "Set points on {0} in Jira (the source ticket has {1}), then "
            "re-run.".format(twin_key, source["points"])
        )

    labels = fields.get("labels") or []
    if acli.BENCH_LABEL not in labels:
        raise TwinTicketError(
            "twin ticket {0} does not carry the `{1}` label, so /bench:cleanup "
            "cannot find it. Its story branch would survive cleanup and the "
            "next run on this twin would reuse that branch instead of starting "
            "fresh. Add the label to {0}.".format(twin_key, acli.BENCH_LABEL)
        )

    twin_acs, source_acs = _ac_lines(twin["acs"]), _ac_lines(source["acs"])
    if twin_acs != source_acs:
        # Zero extracted is its own diagnosis, and a common one: acceptance
        # criteria are found by looking for a HEADING node in the description's
        # ADF, so a description pasted or generated as one flat paragraph yields
        # nothing even though the text is plainly there to a human reader.
        empty_hint = (
            "\nNone were extracted at all, which usually means {0}'s description "
            "is a single flat paragraph rather than structured content -- "
            "criteria are located by an 'Acceptance Criteria' HEADING, so text "
            "that merely says those words inside a paragraph is invisible. Copy "
            "{1}'s description across as structured content (acli "
            "`--description-file` with {1}'s ADF) rather than retyping it."
        ).format(twin_key, source["key"]) if not twin_acs else ""
        raise TwinTicketError(
            "twin ticket {0} has different acceptance criteria from {1} "
            "({2} vs {3} criteria). Graders score this cell's diff against "
            "{1}'s criteria, so the session would implement one spec and be "
            "marked against another.{4}".format(
                twin_key, source["key"], len(twin_acs), len(source_acs), empty_hint
            )
        )

    return twin


def _ac_lines(acs: str) -> list:
    """Acceptance criteria as comparable lines, whitespace-insensitive.

    Compared rather than the whole description because a twin legitimately
    differs in the parts that are not the spec -- a title prefix, a note about
    which cell it belongs to. The criteria are what gets graded.
    """
    out = []
    for line in (acs or "").splitlines():
        stripped = line.strip().lstrip("-*+ ").strip()
        if stripped:
            out.append(" ".join(stripped.split()))
    return out


def git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo)] + list(args), capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout.strip()


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--story", required=True)
    parser.add_argument("--approach", required=True)
    parser.add_argument(
        "--version",
        default=None,
        help=(
            "Plugin version this cell measures (e.g. 0.44.0). Namespaces the "
            "branch, worktree and artifacts as <approach>@<version> so two "
            "versions of one approach can be compared without collision. Must "
            "match the adapter's version.version; execute.py enforces that."
        ),
    )
    parser.add_argument(
        "--adapter",
        required=True,
        help=(
            "Path to the approach YAML. Required: the adapter declares the "
            "exact plugin set the measured session may load, and without it "
            "the worktree inherits whatever plugins the operator has enabled "
            "-- which is the difference between measuring an approach and "
            "measuring this machine."
        ),
    )
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument(
        "--base-sha", default=None
    )
    parser.add_argument(
        "--twin-ticket",
        default=None,
        help=(
            "Pre-made Jira ticket this cell works against, REQUIRED for an "
            "adapter that sets `dedicated_ticket: true`. Must have story points "
            "set, carry the bench-run label, and share the source ticket's "
            "acceptance criteria. The harness cannot create it: acli on this "
            "build cannot write story points by any route."
        ),
    )
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    cfg = config.load_config(repo, {})
    story = json.loads(Path(args.story).read_text())
    ticket = story["key"]

    # Before anything else: if a previous cell was killed before it could
    # restore installed_plugins.json, put it back. Left alone, this machine's
    # plugin registrations stay rewritten and every later cell measures
    # whatever that run happened to leave behind.
    recovery = plugins.recover_if_abandoned()
    if recovery:
        print("  " + recovery)

    adapter = adapters.load_adapter(Path(args.adapter))

    cell_name = cell_id(args.approach, args.version)
    # execute.py makes the same assertion before spending anything. Making it
    # here too means a mismatch costs one provisioning call rather than a
    # worktree that has to be torn down.
    if cell_name != adapter.cell_id:
        raise UnsafeBranchError(
            "adapter/flag mismatch: --approach/--version resolve to {0!r} but "
            "{1} resolves to {2!r}.".format(cell_name, args.adapter, adapter.cell_id)
        )

    branch = branch_name(ticket, cell_name, args.run_id)
    assert_bench_branch(branch)

    base_sha = args.base_sha or git(repo, "rev-parse", cfg.base_branch)
    worktree = repo / ".bench-worktrees" / f"{ticket}-{cell_name}-{args.run_id}"
    # run_id is part of the path so the same cell can be run repeatedly
    # without each run destroying the previous one's evidence. Repeats are
    # what gives a delta a noise floor: without them, a small difference
    # between two versions cannot be told apart from sampling spread.
    artifacts = repo / "docs" / "benchmarks" / ticket / cell_name / args.run_id / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)

    # The issue the SESSION works against. Distinct from `ticket`, which stays
    # the source key so every cell's artifacts, branch and report row file
    # under one story and the comparison can group them. Only the prompt, the
    # Jira writes and the guard's ref allow-list follow the twin key.
    #
    # Validated BEFORE the worktree exists: every failure mode in validate_twin
    # produces a cell whose numbers look real and describe something else, so
    # they are all worth one Jira read to rule out.
    twin_key = None
    if adapter.dedicated_ticket:
        if not args.twin_ticket:
            raise TwinTicketError(
                "adapter {0} sets `dedicated_ticket: true` but no --twin-ticket "
                "was given. This approach writes to Jira and derives its git "
                "branch from the story key, so it needs a ticket of its own: two "
                "cells sharing one would share a branch, and the playbook reuses "
                "an existing branch rather than duplicating it -- the second cell "
                "would check out the first's finished work and measure nothing.\n"
                "Create a twin of {1} with story points set and the `{2}` label, "
                "then pass --twin-ticket <KEY>.".format(
                    args.adapter, ticket, acli.BENCH_LABEL
                )
            )
        twin = validate_twin(args.twin_ticket, story, cfg.story_points_field)
        twin_key = twin["key"]
    elif args.twin_ticket:
        raise TwinTicketError(
            "--twin-ticket {0} was given, but adapter {1} does not set "
            "`dedicated_ticket: true` -- it never writes to Jira, so the twin "
            "would go unused and the row would silently not be what you "
            "intended.".format(args.twin_ticket, args.adapter)
        )

    git(repo, "worktree", "add", "-b", branch, str(worktree), base_sha)
    env_record = environment.environment_record(adapter.plugins, repo)
    guard_script = Path(__file__).resolve().parent / "bench_guard.py"
    guard_path = write_guard_config(
        worktree, twin_key or ticket, branch, cell_name
    )
    settings_path = write_bench_settings(
        worktree,
        enabled_plugins=env_record["enabled_plugins"],
        extra_allow=adapter.permissions,
        guard_script=guard_script,
    )

    cell = {
        "ticket": ticket,
        "twin_ticket": twin_key,
        "guard_config": str(guard_path),
        # The versioned identity: what paths, the branch and the report row
        # are keyed on. `approach_id` keeps the unversioned name so a report
        # can group two versions of one approach together.
        "approach": cell_name,
        "approach_id": args.approach,
        "version": args.version,
        "run_id": args.run_id,
        "branch": branch,
        "worktree": str(worktree),
        "artifacts": str(artifacts),
        "base_sha": base_sha,
        "repo": str(repo),
        "settings_local": str(settings_path),
        # What this cell's session runs inside. execute.py copies it into
        # result.json so the run record carries it without re-deriving it
        # from a machine that may have changed since.
        "environment": env_record,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cell, indent=2))
    print(f"provisioned {branch} at {worktree}")
    print(f"  wrote {settings_path} (harness permissions: git commit + test runner)")
    if twin_key:
        print(
            "  twin Jira issue: {0} (points={1}) -- this cell's comments and PR "
            "land there; {2} is not written to".format(
                twin_key, twin["points"], ticket
            )
        )
    print(
        "  push guard: {0} (refs allowed: {1})".format(
            guard_path, ", ".join(allowed_refs(twin_key or ticket, branch))
        )
    )
    print(
        "  plugins enabled: {0}".format(", ".join(adapter.plugins) or "NONE")
    )
    print(
        "  plugins explicitly disabled: {0}".format(
            len(env_record["disabled_plugins"])
        )
    )
    if env_record["ambient_hooks"]:
        # Not suppressible from a project settings file, so it is stated at
        # provisioning time rather than discovered in the report.
        print(
            "  WARNING: {0} hook(s) from user/project settings will run inside "
            "the measured session and cannot be disabled from here:".format(
                len(env_record["ambient_hooks"])
            )
        )
        for hook in env_record["ambient_hooks"]:
            print("    {0}: {1}".format(hook["event"], hook["command"]))
    return 0


if __name__ == "__main__":
    # A refusal is an operator-facing message, not a crash. A traceback buries
    # the one line that says what to do, and these messages exist precisely to
    # say what to do.
    try:
        raise SystemExit(main())
    except (TwinTicketError, UnsafeBranchError) as exc:
        print("REFUSED: {0}".format(exc), file=sys.stderr)
        # 2 distinguishes a deliberate refusal from a crash, matching
        # preflight.py.
        raise SystemExit(2)
