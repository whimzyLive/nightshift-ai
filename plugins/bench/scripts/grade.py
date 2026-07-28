#!/usr/bin/env python3
"""Grade a cell's output blind.

Blinding is structural: this script receives a hash-named directory and the
original acceptance criteria, and never learns which approach produced the diff.
Process artifacts are stripped from the graded diff but are preserved intact in
the cell's artifacts directory — a plan document is real output, it is simply not
evidence of code correctness.

Usage:
  python3 grade.py --cell cell.json --story story.json --out grades.json
"""
import argparse
import hashlib
import json
import re
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

STRIP_PATTERNS = [
    "docs/superpowers/",
    "docs/features/",
    "docs/benchmarks/",
    ".specify/",
    "CHANGELOG.md",
]

_TRAILER = re.compile(r"^[+\-].*(Claude-Session:|Co-Authored-By:|claude\.ai/code/session)")
_FILE_HEADER = re.compile(r"^diff --git a/(\S+) b/(\S+)")

GRADER_COUNT = 3


def filter_diff(diff_text: str) -> str:
    """Drop process-artifact file sections and identifying trailers."""
    out: List[str] = []
    keeping = True
    for line in diff_text.splitlines():
        header = _FILE_HEADER.match(line)
        if header:
            path = header.group(1)
            keeping = not any(pattern in path for pattern in STRIP_PATTERNS)
        if not keeping:
            continue
        if _TRAILER.match(line):
            continue
        out.append(line)
    return "\n".join(out)


def cell_hash(cell: dict) -> str:
    seed = "{0}|{1}|{2}".format(cell["ticket"], cell["approach"], cell["run_id"])
    return "cell-" + hashlib.sha256(seed.encode()).hexdigest()[:8]


def grader_prompt(acs: str, diff_text: str, tests_text: str) -> str:
    """Everything the grader may see is inlined here.

    The alternative — pointing the grader at a directory and letting it read files —
    gives it a working directory it can escape. One `..` reaches the real repository,
    where branch names and plan documents identify the approach immediately.
    """
    return (
        "You are reviewing a code change. You do not know how it was produced, you have no way "
        "to find out, and you must not speculate about it.\n\n"
        "Acceptance criteria:\n{0}\n\n"
        "Test output:\n```\n{1}\n```\n\n"
        "Diff under review:\n```diff\n{2}\n```\n\n"
        "Reply with ONLY a JSON object, no prose, in this exact shape:\n"
        '{{"acs": [{{"id": "AC1", "met": true, "evidence": "quote from the diff"}}], '
        '"findings": [{{"severity": "high|medium|low", "summary": "one sentence"}}], '
        '"regressions": false, "first_fix_round_items": 0}}\n'
    ).format(acs, tests_text, diff_text)


def build_blind_dir(cell: dict, story: dict, base: Path) -> Path:
    target = base / cell_hash(cell)
    target.mkdir(parents=True, exist_ok=True)

    diff = subprocess.run(
        ["git", "-C", cell["worktree"], "diff", cell["base_sha"], "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    (target / "diff.patch").write_text(filter_diff(diff))
    (target / "acs.md").write_text(story["acs"])
    tests = Path(cell["artifacts"]) / "tests.txt"
    (target / "tests.txt").write_text(tests.read_text() if tests.exists() else "not run")
    return target


def run_grader(blind_dir: Path, acs: str) -> dict:
    diff_text = (blind_dir / "diff.patch").read_text()
    tests_text = (blind_dir / "tests.txt").read_text()
    proc = subprocess.run(
        ["claude", "--print", "--output-format", "json"],
        cwd=str(blind_dir),
        input=grader_prompt(acs, diff_text, tests_text),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"grader failed: {proc.stderr.strip()}")
    payload = json.loads(proc.stdout)
    text = payload.get("result", "")
    start = text.find("{")
    if start < 0:
        raise ValueError("grader returned no JSON object")
    return json.loads(text[start:])


def reduce_verdicts(verdicts: List[dict]) -> dict:
    acs: Dict[str, dict] = {}
    for verdict in verdicts:
        for item in verdict.get("acs") or []:
            acs.setdefault(item["id"], {"votes": [], "evidence": []})
            acs[item["id"]]["votes"].append(bool(item.get("met")))
            if item.get("evidence"):
                acs[item["id"]]["evidence"].append(item["evidence"])

    reduced_acs = {}
    for ac_id, data in acs.items():
        votes = data["votes"]
        met = sum(1 for v in votes if v) >= 2
        reduced_acs[ac_id] = {
            "met": met,
            "votes": votes,
            "disagreement": len(set(votes)) > 1,
            "evidence": data["evidence"][:1],
        }

    counts = [len(v.get("findings") or []) for v in verdicts]
    fix_items = [int(v.get("first_fix_round_items") or 0) for v in verdicts]
    regressions = [bool(v.get("regressions")) for v in verdicts]

    return {
        "acs": reduced_acs,
        "findings_count": int(statistics.median(counts)) if counts else 0,
        "first_fix_round_items": int(statistics.median(fix_items)) if fix_items else 0,
        "regressions": sum(1 for r in regressions if r) >= 2,
        "grader_count": len(verdicts),
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--story", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--graders", type=int, default=GRADER_COUNT)
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    story = json.loads(Path(args.story).read_text())

    blind_base = Path(cell["artifacts"]).parent / "blind"
    blind_dir = build_blind_dir(cell, story, blind_base)

    verdicts = [run_grader(blind_dir, story["acs"]) for _ in range(args.graders)]
    reduced = reduce_verdicts(verdicts)
    reduced["blind_dir"] = str(blind_dir)
    reduced["raw_verdicts"] = verdicts

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(reduced, indent=2))
    met = sum(1 for ac in reduced["acs"].values() if ac["met"])
    print(f"graded {blind_dir.name}: {met}/{len(reduced['acs'])} ACs met, "
          f"{reduced['findings_count']} findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
