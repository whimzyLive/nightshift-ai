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
import subprocess
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import config  # noqa: E402

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

BENCH_DENIED_PERMISSIONS = [
    "Bash(git push:*)",
    "Bash(git merge:*)",
    "Bash(git rebase:*)",
    "Bash(gh pr merge:*)",
]

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


def write_bench_settings(worktree: Path) -> Path:
    """Write .claude/settings.local.json into a benchmark worktree.

    Provisioning owns this, not execute.py: the file is a property of the
    WORKTREE, created in the same step that creates the worktree, so the
    worktree is never in a state where it exists but cannot be worked in.
    It also keeps the measured window clean -- execute.py's timer starts at
    the session, and writing permissions is setup, not measured work.
    """
    settings_dir = worktree / ".claude"
    settings_dir.mkdir(parents=True, exist_ok=True)
    target = settings_dir / "settings.local.json"
    target.write_text(
        json.dumps(
            {
                "_comment": SETTINGS_RATIONALE,
                "permissions": {
                    "allow": BENCH_PERMISSIONS,
                    "deny": BENCH_DENIED_PERMISSIONS,
                },
            },
            indent=2,
        )
        + "\n"
    )
    return target


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
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--base-sha", default=None)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    cfg = config.load_config(repo, {})
    story = json.loads(Path(args.story).read_text())
    ticket = story["key"]

    cell_name = cell_id(args.approach, args.version)
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

    git(repo, "worktree", "add", "-b", branch, str(worktree), base_sha)
    settings_path = write_bench_settings(worktree)

    cell = {
        "ticket": ticket,
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
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cell, indent=2))
    print(f"provisioned {branch} at {worktree}")
    print(f"  wrote {settings_path} (harness permissions: git commit + test runner)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
