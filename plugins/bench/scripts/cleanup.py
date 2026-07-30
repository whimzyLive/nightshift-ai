#!/usr/bin/env python3
"""Enumerate and remove what a benchmark sweep left behind.

A sweep leaves `bench/` branches, worktrees, draft pull requests, and -- for
approaches that write to Jira -- a story branch named after the twin ticket.

What it does NOT remove is the twin tickets themselves. Those are hand-made,
with story points acli cannot write, so deleting one destroys setup the operator
has to redo. Their BRANCHES are another matter and must go: the SDLC playbook
reuses an existing `feat/<KEY>` branch rather than duplicating it, so a leftover
one makes the next run on that twin check out the previous run's finished work
and measure nothing.

Two hard rules:

* **Plan first, act second.** `plan()` only reads. Nothing is destroyed
  without the caller printing the plan and passing `--confirm`.
* **Label evidence, not memory.** Twins are found by JQL on the `bench-run`
  label rather than from cell records: a sweep that crashed before writing its
  records still leaves findable twins, and a hand-edited record must never be
  able to aim a deletion at someone's real ticket.

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


def _branch_name(line: str) -> str:
    """The branch name from one `git branch --list` line.

    Git marks the CURRENT branch with `*` and a branch checked out in another
    WORKTREE with `+`. Only `*` was stripped, so a worktree-checked-out branch
    parsed as "+ bench/..." and was silently dropped -- and since plan() runs
    before the worktree is removed, that was always the branch cleanup most
    needed to delete. It reported "Branches to delete (0)" while the branch sat
    there.
    """
    return line.strip().lstrip("*+ ").strip()


def bench_branches(repo: Path, ticket: str) -> List[str]:
    out = git(repo, "branch", "--list", "{0}{1}/*".format(BENCH_PREFIX, ticket))
    branches = []
    for line in out.splitlines():
        name = _branch_name(line)
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


def twin_issues(project: str) -> List[str]:
    """Bench-labelled issues in this project -- the operator's twin tickets.

    These are NEVER deleted. The operator creates them by hand, with story
    points set, precisely because acli cannot write points; deleting one means
    that setup has to be redone. They are reported so a reader knows which
    tickets a sweep touched, and so the branch sweep below knows which story
    branches to look for.

    Discovered by label rather than from cell records: a sweep that crashed
    before writing its records still leaves findable twins, and a hand-edited
    record must never be able to aim a deletion at a real ticket.
    """
    return acli.search_by_label(project)


def twin_branches(repo: Path, twin_keys: List[str]) -> List[str]:
    """`feat/<TWIN>` and `fix/<TWIN>` branches left behind by a cell.

    These MUST go even though the twin stays. The SDLC playbook reuses an
    existing story branch rather than creating a duplicate, so a leftover
    `feat/<TWIN>` makes the next run on that twin check out the previous run's
    finished work and measure nothing -- the exact collision twins exist to
    avoid, reintroduced by not cleaning up.
    """
    found = []
    for key in twin_keys:
        for prefix in ("feat", "fix"):
            out = git(repo, "branch", "--list", "{0}/{1}".format(prefix, key))
            for line in out.splitlines():
                name = _branch_name(line)
                if name:
                    found.append(name)
    return found


def draft_prs(repo: Path, ticket: str, twin_keys: List[str]) -> List[dict]:
    """Open PRs raised by this sweep.

    Matched on head branch, which is the only property tying a PR back to a
    cell: the SDLC approach names its branch after its twin ticket, other
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
        if any(head.endswith("/{0}".format(key)) for key in twin_keys):
            wanted.append(row)
    return wanted


def plan(repo: Path, ticket: str, project: str) -> Dict[str, object]:
    """Read-only. Everything cleanup would touch, and nothing touched."""
    twins = twin_issues(project) if project else []
    return {
        "ticket": ticket,
        "branches": bench_branches(repo, ticket) + twin_branches(repo, twins),
        "worktrees": bench_worktrees(repo, ticket),
        # Reported, never deleted -- see twin_issues.
        "twin_issues": twins,
        "pull_requests": draft_prs(repo, ticket, twins),
    }


def render_plan(data: Dict[str, object]) -> str:
    lines = ["Cleanup plan for {0}".format(data["ticket"]), ""]
    for label, key in (
        ("Draft pull requests to close", "pull_requests"),
        ("Twin Jira issues (KEPT — you created these by hand)", "twin_issues"),
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

    Worktrees before branches, because a checked-out branch cannot be deleted.
    Twin issues are reported last and never touched.
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

    for key in data["twin_issues"] or []:
        # Deliberately not deleted. A twin carries hand-set story points that
        # acli cannot restore, so destroying one costs the operator that setup
        # for no benefit -- its branch and PR are what actually need clearing,
        # and both are handled above.
        log.append("kept twin issue {0} (branch and PR cleared; points intact)".format(key))
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
