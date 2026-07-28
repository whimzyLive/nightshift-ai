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
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--base-sha", default=None)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    cfg = config.load_config(repo, {})
    story = json.loads(Path(args.story).read_text())
    ticket = story["key"]

    branch = branch_name(ticket, args.approach, args.run_id)
    assert_bench_branch(branch)

    base_sha = args.base_sha or git(repo, "rev-parse", cfg.base_branch)
    worktree = repo / ".bench-worktrees" / f"{ticket}-{args.approach}-{args.run_id}"
    artifacts = repo / "docs" / "benchmarks" / ticket / args.approach / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)

    git(repo, "worktree", "add", "-b", branch, str(worktree), base_sha)

    cell = {
        "ticket": ticket,
        "approach": args.approach,
        "run_id": args.run_id,
        "branch": branch,
        "worktree": str(worktree),
        "artifacts": str(artifacts),
        "base_sha": base_sha,
        "repo": str(repo),
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cell, indent=2))
    print(f"provisioned {branch} at {worktree}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
