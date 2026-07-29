#!/usr/bin/env python3
"""Enumerate and remove what a benchmark sweep left behind.

A sweep now creates real artefacts: scratch Jira issues, `bench/` branches,
worktrees and draft pull requests. Cleanup is a first-class command rather
than a manual chore because the alternative is a Jira project that slowly
fills with `[bench …]` issues nobody can safely delete later.

Two hard rules:

* **Plan first, act second.** `plan()` only reads. Nothing is destroyed
  without the caller printing the plan and passing `--confirm`, because
  issue deletion is irreversible and a mis-scoped query is the one failure
  mode with no undo.
* **Label evidence, not memory.** Scratch issues are found by JQL on the
  `bench-run` label, and an issue that does not carry it is never deleted --
  even if it appears in a cell record. A sweep that crashed before writing
  its records still leaves findable issues; a hand-edited record must not be
  able to point deletion at someone's real ticket.

Usage:
  python3 cleanup.py --ticket NA-68 --repo . [--confirm]
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import acli, config  # noqa: E402

BENCH_PREFIX = "bench/"


def git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo)] + list(args), capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise RuntimeError("git {0} failed: {1}".format(" ".join(args), proc.stderr.strip()))
    return proc.stdout.strip()


def bench_branches(repo: Path, ticket: str) -> List[str]:
    out = git(repo, "branch", "--list", "{0}{1}/*".format(BENCH_PREFIX, ticket))
    branches = []
    for line in out.splitlines():
        name = line.strip().lstrip("* ").strip()
        # Belt and braces: the glob above should make this impossible, but a
        # deletion loop is the wrong place to trust a glob.
        if name.startswith(BENCH_PREFIX):
            branches.append(name)
    return branches


def bench_worktrees(repo: Path, ticket: str) -> List[str]:
    out = git(repo, "worktree", "list", "--porcelain")
    found = []
    for line in out.splitlines():
        if not line.startswith("worktree "):
            continue
        path = line[len("worktree ") :].strip()
        if ".bench-worktrees" in path and "{0}-".format(ticket) in Path(path).name:
            found.append(path)
    return found


def scratch_issues(project: str, ticket: str) -> List[str]:
    """Bench-labelled issues that name this ticket as their source.

    Filtered by BOTH the label and the source reference. The label alone
    would sweep in another ticket's cells; the source reference alone would
    trust text over the label that marks an issue as ours.
    """
    keys = []
    for key in acli.search_by_label(project):
        try:
            fields = acli.fetch_issue(key)
        except acli.AcliError:
            continue
        body = acli.issue_description(fields)
        labels = fields.get("labels") or []
        if acli.BENCH_LABEL in labels and ticket in body:
            keys.append(key)
    return keys


def draft_prs(repo: Path, ticket: str, scratch_keys: List[str]) -> List[dict]:
    """Open PRs raised by this sweep.

    Matched on head branch, which is the only property tying a PR back to a
    cell: the SDLC approach names its branch after the scratch issue, other
    approaches push the `bench/` branch itself.
    """
    proc = subprocess.run(
        [
            "gh",
            "pr",
            "list",
            "--state",
            "open",
            "--limit",
            "200",
            "--json",
            "number,title,headRefName,isDraft,url",
        ],
        cwd=str(repo),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return []
    try:
        rows = json.loads(proc.stdout or "[]")
    except ValueError:
        return []

    wanted = []
    for row in rows:
        head = row.get("headRefName") or ""
        if head.startswith("{0}{1}/".format(BENCH_PREFIX, ticket)):
            wanted.append(row)
            continue
        if any(head.endswith("/{0}".format(key)) for key in scratch_keys):
            wanted.append(row)
    return wanted


def plan(repo: Path, ticket: str, project: str) -> Dict[str, object]:
    """Read-only. Everything cleanup would touch, and nothing touched."""
    keys = scratch_issues(project, ticket) if project else []
    return {
        "ticket": ticket,
        "branches": bench_branches(repo, ticket),
        "worktrees": bench_worktrees(repo, ticket),
        "scratch_issues": keys,
        "pull_requests": draft_prs(repo, ticket, keys),
    }


def render_plan(data: Dict[str, object]) -> str:
    lines = ["Cleanup plan for {0}".format(data["ticket"]), ""]
    for label, key in (
        ("Draft pull requests to close", "pull_requests"),
        ("Scratch Jira issues to DELETE (irreversible)", "scratch_issues"),
        ("Worktrees to remove", "worktrees"),
        ("Branches to delete", "branches"),
    ):
        items = data[key] or []
        lines.append("{0} ({1}):".format(label, len(items)))
        if not items:
            lines.append("  (none)")
        for item in items:
            if isinstance(item, dict):
                lines.append(
                    "  #{0} {1} [{2}]".format(
                        item.get("number"),
                        item.get("title", ""),
                        "draft" if item.get("isDraft") else "READY, not draft",
                    )
                )
            else:
                lines.append("  {0}".format(item))
        lines.append("")
    return "\n".join(lines)


def execute(repo: Path, data: Dict[str, object]) -> List[str]:
    """Destroy what `plan` found. Ordered so nothing is orphaned.

    Worktrees before branches (a checked-out branch cannot be deleted), and
    Jira issues last, so a failure earlier leaves the issue -- the one record
    that makes the rest findable again.
    """
    log: List[str] = []
    for pr in data["pull_requests"] or []:
        proc = subprocess.run(
            ["gh", "pr", "close", str(pr.get("number"))],
            cwd=str(repo),
            capture_output=True,
            text=True,
        )
        log.append(
            "closed PR #{0}".format(pr.get("number"))
            if proc.returncode == 0
            else "FAILED to close PR #{0}: {1}".format(
                pr.get("number"), proc.stderr.strip()
            )
        )

    for path in data["worktrees"] or []:
        try:
            git(repo, "worktree", "remove", "--force", path)
            log.append("removed worktree {0}".format(path))
        except RuntimeError as exc:
            log.append("FAILED to remove worktree {0}: {1}".format(path, exc))

    for branch in data["branches"] or []:
        try:
            git(repo, "branch", "-D", branch)
            log.append("deleted branch {0}".format(branch))
        except RuntimeError as exc:
            log.append("FAILED to delete branch {0}: {1}".format(branch, exc))

    for key in data["scratch_issues"] or []:
        try:
            acli.delete_issue(key)
            log.append("deleted issue {0}".format(key))
        except acli.AcliError as exc:
            log.append("FAILED to delete issue {0}: {1}".format(key, exc))
    return log


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticket", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument(
        "--confirm",
        action="store_true",
        help=(
            "Actually delete. Without it this prints the plan and exits, "
            "because Jira issue deletion is irreversible."
        ),
    )
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    cfg = config.load_config(repo, {})
    data = plan(repo, args.ticket, cfg.jira_project)
    print(render_plan(data))

    if not args.confirm:
        print("Dry run. Re-run with --confirm to delete the above.")
        return 0

    for line in execute(repo, data):
        print("  " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
