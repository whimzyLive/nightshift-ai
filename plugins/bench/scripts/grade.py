#!/usr/bin/env python3
"""Grade a cell's output blind.

Blinding is structural: this script receives a hash-named directory and the
original acceptance criteria, and never learns which approach produced the diff.
Process artifacts are stripped from the graded diff but are preserved intact in
the cell's artifacts directory — a plan document is real output, it is simply not
evidence of code correctness.

Blinding rests on three independent properties, not on any single one being
airtight:

  1. Path: blind_dir (see blind_base_dir) is keyed by repo + ticket only.
     The approach never appears in any path segment, so a `pwd`, an `ls ..`,
     or a stray error message that echoes a path cannot reveal it — no
     `..`-traversal is even required to leak it if the path itself named the
     approach, which is why this matters as much as the traversal risk.
  2. Content: filter_diff drops process-artifact file sections by path AND
     redacts approach-identifying content (alias phrases per approach —
     see APPROACH_REDACTION_ALIASES — and bench/<ticket>/<approach>/<run-id>
     branch references) from what survives, because a diff's content is
     free text an approach can name itself in (a comment, a commit message
     fragment) using whatever phrasing a model actually writes, not just
     its internal id string. `opus` is a deliberate, documented exception —
     see APPROACH_REDACTION_ALIASES.
  3. Inputs: grader_prompt inlines the diff and test output as strings.
     cell_hash is NOT a secret and provides directory de-identification, not
     preimage resistance — (ticket, approach, run_id) is a small enough
     space to brute-force in milliseconds. That is fine: the grader process
     is never given cell_hash's inputs, or cell_hash itself, so there is
     nothing for it to invert. If cell.json later grows a per-run random
     `salt` field, cell_hash will incorporate it automatically (see below),
     which raises the brute-force cost, but that is defense in depth on top
     of (1) and (2), not the load-bearing property.

Usage:
  python3 grade.py --cell cell.json --story story.json --out grades.json
"""
import argparse
import hashlib
import json
import re
import statistics
import subprocess
from pathlib import Path
from typing import Callable, Dict, List, Optional

STRIP_PATTERNS = [
    "docs/superpowers/",
    "docs/features/",
    "docs/benchmarks/",
    ".specify/",
    "CHANGELOG.md",
]

# Known approach ids. Used for path-safety purposes (e.g. blind_base_dir
# must never surface any of these in a path). NOT all of these are redacted
# from diff content — see APPROACH_REDACTION_ALIASES below for that.
APPROACH_IDS = ["opus", "sdlc", "superpowers", "speckit"]

# Alias phrases a model might actually write in diff content to name the
# approach that produced it, keyed by approach id. Redaction has to cover
# the forms a model would actually write, not just the internal id string —
# e.g. speckit's real product name is the hyphenated "spec-kit" (as it
# appears in this repo's own adapter label, "GitHub spec-kit"), which a
# model is far more likely to write in prose/comments than the bare
# "speckit" id, and "specify-cli" (the CLI the adapter installs) uniquely
# identifies this approach too.
#
# `opus` is deliberately NOT a key here: redacting the bare model name would
# mangle legitimate content, since model names show up in code and config
# for reasons unrelated to which approach produced a diff (this repo's own
# source references Claude model ids). This is an accepted, documented
# blinding gap for that one case — grader_prompt's instruction not to
# speculate about provenance is what has to carry it.
APPROACH_REDACTION_ALIASES: Dict[str, List[str]] = {
    "sdlc": ["sdlc"],
    "superpowers": ["superpowers"],
    "speckit": ["speckit", "spec-kit", "spec kit", "specify-cli"],
}

_REDACTED = "[REDACTED]"

_TRAILER = re.compile(r"^[+\-].*(Claude-Session:|Co-Authored-By:|claude\.ai/code/session)")

# `diff --git a/<path> b/<path>` header, plain (whitespace-delimited) form.
_FILE_HEADER_PLAIN = re.compile(r"^diff --git a/(\S+) b/\S+\s*$")
# Git quotes the whole `"a/..." "b/..."` pair when a path needs escaping
# (e.g. it contains spaces). The plain regex above never matches those
# lines, which — left unhandled — leaves `keeping` stuck on whatever the
# previous file section decided instead of being reset for this one.
_FILE_HEADER_QUOTED = re.compile(r'^diff --git "a/(.+)" "b/.+"\s*$')

_BRANCH_REF = re.compile(r"bench/[^\s/]+/[^\s/]+/[^\s/]+")

# Longest-alias-first: keeps ordering correct if future aliases overlap
# (none of the current ones do, but a shorter alias that happens to be a
# prefix of a longer one should never shadow it).
_ALIAS_TERMS = sorted(
    {alias for aliases in APPROACH_REDACTION_ALIASES.values() for alias in aliases},
    key=len,
    reverse=True,
)
_APPROACH_ALIAS = re.compile(
    r"\b(" + "|".join(re.escape(term) for term in _ALIAS_TERMS) + r")\b", re.IGNORECASE
)

GRADER_COUNT = 3


def _diff_header_path(line: str) -> Optional[str]:
    """Return the `a/`-side path from a `diff --git` header line, or None."""
    m = _FILE_HEADER_QUOTED.match(line)
    if m:
        return m.group(1)
    m = _FILE_HEADER_PLAIN.match(line)
    if m:
        return m.group(1)
    return None


def _redact_approach_tokens(line: str) -> str:
    """Redact approach-identifying content from a single diff line.

    Branch references are redacted whole (before alias-level redaction would
    otherwise mangle them into a still-identifiable fragment), then any
    remaining approach alias phrase (see APPROACH_REDACTION_ALIASES — whole
    word/phrase, case-insensitive) is redacted individually. Replacement
    (not deletion) keeps line count and diff structure intact. `opus` is
    deliberately excluded from alias redaction — see
    APPROACH_REDACTION_ALIASES for why.
    """
    line = _BRANCH_REF.sub(_REDACTED, line)
    line = _APPROACH_ALIAS.sub(_REDACTED, line)
    return line


def filter_diff(diff_text: str) -> str:
    """Drop process-artifact file sections, identifying trailers, and
    approach-identifying content tokens from surviving lines."""
    out: List[str] = []
    keeping = True
    for line in diff_text.splitlines():
        path = _diff_header_path(line)
        if path is not None:
            keeping = not any(pattern in path for pattern in STRIP_PATTERNS)
        if not keeping:
            continue
        if _TRAILER.match(line):
            continue
        out.append(_redact_approach_tokens(line))
    return "\n".join(out)


def cell_hash(cell: dict) -> str:
    """Stable, approach-independent directory name for a cell.

    NOT preimage-resistant — see module docstring. `cell.get("salt")` is
    folded in when present (empty string when absent, so this is backward
    compatible with cell.json documents that don't have one) purely as a
    cheap defense-in-depth measure; nothing in this module's blinding
    guarantee depends on it being set.
    """
    seed = "{0}|{1}|{2}|{3}".format(
        cell["ticket"], cell["approach"], cell["run_id"], cell.get("salt", "")
    )
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


def blind_base_dir(cell: dict) -> Path:
    """Root directory for this ticket's blind grading directories.

    Deliberately keyed by repo + ticket only, never by approach: a blind_dir
    path that names the approach anywhere lets the grader recover it via a
    bare `pwd`, an `ls ..`, or any tool error that echoes a path — no
    `..`-traversal required. cell["artifacts"] (written by provision.py) is
    NOT a safe base for this reason — it is
    `<repo>/docs/benchmarks/<ticket>/<approach>/artifacts`, two segments
    away from the approach name.
    """
    return Path(cell["repo"]) / "docs" / "benchmarks" / cell["ticket"] / "blind"


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


def collect_verdicts(
    blind_dir: Path,
    acs: str,
    count: int,
    grader_fn: Callable[[Path, str], dict] = run_grader,
) -> dict:
    """Run `count` graders, retrying a failing grader once before giving up
    on it. Each grader call costs real money, so one flaky call must not
    throw away the others: this proceeds once a majority of graders produced
    a verdict, and raises only if fewer than a majority succeeded.

    Returns {"verdicts": [...succeeded, in order...], "failures": ["error
    text", ...]} — `failures` records one entry per grader slot that never
    produced a verdict even after its retry.
    """
    verdicts: List[dict] = []
    failures: List[str] = []
    for _ in range(count):
        verdict = None
        last_error = None
        for _attempt in range(2):  # initial try + one retry
            try:
                verdict = grader_fn(blind_dir, acs)
                break
            except Exception as exc:  # noqa: BLE001 - any grader failure is retryable
                last_error = str(exc)
        if verdict is not None:
            verdicts.append(verdict)
        else:
            failures.append(last_error or "unknown grader failure")

    required = count // 2 + 1
    if len(verdicts) < required:
        raise RuntimeError(
            "only {0}/{1} graders succeeded (need >= {2}): {3}".format(
                len(verdicts), count, required, failures
            )
        )
    return {"verdicts": verdicts, "failures": failures}


def reduce_verdicts(verdicts: List[dict]) -> dict:
    """Reduce independent grader verdicts to one verdict per AC.

    Majority is relative to the votes actually cast for that AC, not to
    len(verdicts): graders are independent LLM calls and may enumerate
    different AC ids, so an AC only one grader mentions must not be punished
    for the other graders having said nothing about it. An exact tie
    resolves to not-met — the burden of proof for "this AC is satisfied"
    sits with the evidence, not the vote count.
    """
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
        yes = sum(1 for v in votes if v)
        met = yes > len(votes) / 2  # strict majority of votes cast; ties -> False
        reduced_acs[ac_id] = {
            "met": met,
            "votes": votes,
            "disagreement": len(set(votes)) > 1,
            "evidence": data["evidence"][:1],
        }

    counts = [len(v.get("findings") or []) for v in verdicts]
    fix_items = [int(v.get("first_fix_round_items") or 0) for v in verdicts]
    regressions = [bool(v.get("regressions")) for v in verdicts]
    regressions_yes = sum(1 for r in regressions if r)

    return {
        "acs": reduced_acs,
        "findings_count": int(statistics.median(counts)) if counts else 0,
        "first_fix_round_items": int(statistics.median(fix_items)) if fix_items else 0,
        "regressions": regressions_yes > len(regressions) / 2 if regressions else False,
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

    blind_dir = build_blind_dir(cell, story, blind_base_dir(cell))

    result = collect_verdicts(blind_dir, story["acs"], args.graders)
    reduced = reduce_verdicts(result["verdicts"])
    reduced["blind_dir"] = str(blind_dir)
    reduced["raw_verdicts"] = result["verdicts"]
    reduced["grader_failures"] = result["failures"]
    reduced["grader_failure_count"] = len(result["failures"])

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(reduced, indent=2))
    met = sum(1 for ac in reduced["acs"].values() if ac["met"])
    print(f"graded {blind_dir.name}: {met}/{len(reduced['acs'])} ACs met, "
          f"{reduced['findings_count']} findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
