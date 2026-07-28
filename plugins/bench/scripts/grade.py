#!/usr/bin/env python3
"""Grade a cell's output blind.

Blinding is structural: this script receives a hash-named directory and the
original acceptance criteria, and never learns which approach produced the diff.
Process artifacts are stripped from the graded diff but are preserved intact in
the cell's artifacts directory — a plan document is real output, it is simply not
evidence of code correctness.

Blinding rests on three independent properties, not on any single one being
airtight:

  1. Isolation: blind_dir (see blind_base_dir) is a fresh temp directory
     OUTSIDE every repository, containing only the blinded inputs. The
     approach never appears in any path segment, there are no sibling cell
     directories for an `ls ..` to enumerate, and — just as important — a
     `claude` process rooted there loads no repository CLAUDE.md, no
     `.claude/` configuration and no installed plugins, so the grader is
     neutral and its context is reproducible. A copy of the same blinded
     inputs is archived under the cell's artifacts for the record; the
     grader never runs from that copy.
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
import shutil
import statistics
import subprocess
import tempfile
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

# File-path substrings whose diff sections are dropped before grading.
#
# The point is not redaction -- it is PRESENCE. A redacted
# `.superpowers/sdd/*/progress.md` hunk still tells the grader it is looking
# at a heavyweight process approach, because the direct-Opus cell can never
# produce one. Any path that only one class of approach can create is a
# perfect tell no matter how thoroughly its contents are scrubbed.
STRIP_PATTERNS = [
    "docs/superpowers/",
    "docs/features/",
    "docs/benchmarks/",
    ".superpowers/",
    ".specify/",
    ".claude/",
    ".agents/",
    "docs/adr/",
    "CHANGELOG.md",
]

# Path patterns that a plain substring cannot express. Plan documents are
# the clearest example: they live under many different roots and carry many
# different names, and every one of them is a process tell.
STRIP_REGEXES = [
    re.compile(r"(^|/)[^/]*plan[^/]*\.md$", re.IGNORECASE),
    re.compile(r"(^|/)plans?/", re.IGNORECASE),
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
            keeping = not (
                any(pattern in path for pattern in STRIP_PATTERNS)
                or any(pattern.search(path) for pattern in STRIP_REGEXES)
            )
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


_AC_BULLET = re.compile(r"^(?:[-*+]|\d+[.)])\s+(.*)$")
# An AC id the ticket author already wrote by hand. Stripped and replaced
# with the harness's own sequential id, so "AC1: does X" never becomes
# "AC1. AC1: does X" and a ticket that numbers its criteria oddly (AC3, AC7)
# still produces a dense, comparable AC1..ACn sequence.
_EXISTING_AC_ID = re.compile(r"^AC\s*\d+\s*[.:)\-]\s*", re.IGNORECASE)


def number_acceptance_criteria(acs_text: str) -> Tuple[str, List[str]]:
    """Assign deterministic AC1..ACn ids to the criteria, harness-side.

    Returns (numbered_text, ids).

    Letting the grader invent its own ids is what makes the ACs column
    incomparable across rows: three independent graders enumerate the same
    criteria differently, so acs_met/acs_total denominators differ between
    approaches -- and comparing approaches is the entire point of the
    report. Numbering here fixes the denominator before any grader sees it.

    Only TOP-LEVEL bullets are numbered. An indented sub-bullet is part of
    its parent criterion, not a criterion of its own (the same nesting
    distinction resolve.py's flattener preserves).
    """
    lines = (acs_text or "").splitlines()
    out: List[str] = []
    ids: List[str] = []
    for line in lines:
        match = _AC_BULLET.match(line) if line[:1] not in (" ", "\t") else None
        if match:
            ac_id = "AC{0}".format(len(ids) + 1)
            ids.append(ac_id)
            out.append("{0}. {1}".format(ac_id, _EXISTING_AC_ID.sub("", match.group(1))))
        else:
            out.append(line)

    if not ids:
        # No bullet list at all -- number each non-empty line instead, so a
        # prose-style AC block still yields stable ids.
        out = []
        for line in lines:
            if line.strip():
                ac_id = "AC{0}".format(len(ids) + 1)
                ids.append(ac_id)
                out.append(
                    "{0}. {1}".format(ac_id, _EXISTING_AC_ID.sub("", line.strip()))
                )
            else:
                out.append(line)

    return "\n".join(out), ids


def grader_prompt(acs: str, diff_text: str, tests_text: str, ac_ids: List[str]) -> str:
    """Everything the grader may see is inlined here.

    The alternative — pointing the grader at a directory and letting it read files —
    gives it a working directory it can escape. One `..` reaches the real repository,
    where branch names and plan documents identify the approach immediately.

    `ac_ids` are assigned by the harness, not the grader. The prompt names
    them explicitly and forbids inventing others, so every row's ACs
    denominator is the same number and the column is comparable.
    """
    id_list = ", ".join(ac_ids) if ac_ids else "(none)"
    return (
        "You are reviewing a code change. You do not know how it was produced, you have no way "
        "to find out, and you must not speculate about it.\n\n"
        "Acceptance criteria (each is prefixed with its id):\n{0}\n\n"
        "Test output:\n```\n{1}\n```\n\n"
        "Diff under review:\n```diff\n{2}\n```\n\n"
        "You MUST return exactly one entry per acceptance criterion, using exactly "
        "these ids and no others: {3}. Do not merge, split, renumber, skip, or "
        "invent ids -- a response using any other id is discarded and re-requested.\n\n"
        "Reply with ONLY a JSON object, no prose, in this exact shape:\n"
        '{{"acs": [{{"id": "AC1", "met": true, "evidence": "quote from the diff"}}], '
        '"findings": [{{"severity": "high|medium|low", "summary": "one sentence"}}], '
        '"regressions": false, "first_fix_round_items": 0}}\n'
    ).format(acs, tests_text, diff_text, id_list)


def validate_verdict(payload: object, allowed_ids: List[str]) -> dict:
    """Return a normalised verdict, or raise ValueError explaining the defect.

    Grader output is untrusted model output, not a data structure. Before
    this existed, reduce_verdicts KeyError'd on a verdict missing `id` and
    TypeError'd on `"acs": "none"` -- and because both escaped the collect
    loop, ONE malformed field discarded all three paid grader calls. Every
    defect found here is raised as a plain ValueError so the caller can
    retry that single grader and keep the others.
    """
    if not isinstance(payload, dict):
        raise ValueError("grader returned {0}, not a JSON object".format(type(payload).__name__))

    raw_acs = payload.get("acs")
    if raw_acs is None:
        raw_acs = []
    if not isinstance(raw_acs, list):
        raise ValueError('grader returned "acs" as {0}, not a list'.format(type(raw_acs).__name__))

    allowed = set(allowed_ids)
    seen = set()
    acs: List[dict] = []
    for item in raw_acs:
        if not isinstance(item, dict):
            raise ValueError("grader returned a non-object entry in \"acs\": {0!r}".format(item))
        ac_id = item.get("id")
        if not isinstance(ac_id, str):
            raise ValueError('grader returned an "acs" entry with no usable id: {0!r}'.format(item))
        if allowed and ac_id not in allowed:
            raise ValueError(
                "grader used unknown acceptance-criterion id {0!r}; allowed ids are {1}".format(
                    ac_id, ", ".join(sorted(allowed))
                )
            )
        if ac_id in seen:
            raise ValueError("grader returned duplicate acceptance-criterion id {0!r}".format(ac_id))
        seen.add(ac_id)
        evidence = item.get("evidence")
        acs.append(
            {
                "id": ac_id,
                "met": bool(item.get("met")),
                "evidence": evidence if isinstance(evidence, str) else "",
            }
        )

    findings = payload.get("findings")
    if findings is None:
        findings = []
    if not isinstance(findings, list):
        raise ValueError(
            'grader returned "findings" as {0}, not a list'.format(type(findings).__name__)
        )

    try:
        fix_items = int(payload.get("first_fix_round_items") or 0)
    except (TypeError, ValueError):
        raise ValueError(
            'grader returned a non-numeric "first_fix_round_items": {0!r}'.format(
                payload.get("first_fix_round_items")
            )
        )

    return {
        "acs": acs,
        "findings": findings,
        "regressions": bool(payload.get("regressions")),
        "first_fix_round_items": fix_items,
    }


def blind_base_dir(cell: dict) -> Path:
    """A fresh temp root for blind grading, OUTSIDE any repository.

    The blind dir was previously
    `<repo>/docs/benchmarks/<ticket>/blind/<hash>` -- inside the repo, and
    the grader's cwd. Two things follow from that, both bad:

      1. `ls ../..` from there lists `opus/`, `sdlc/`, ... each holding a
         cell.json naming its approach, run id and bench branch, plus its
         prompt.txt. The hash-named directory de-identifies itself and then
         sits next to a directory listing that identifies everything.
      2. A `claude` process whose cwd is inside this repository loads the
         repo's CLAUDE.md, its .claude/ configuration and its installed
         plugins into the grader's own context. The grader is then neither
         neutral (it has read this repo's opinions about how work should be
         done) nor reproducible (its context depends on the repo it happens
         to be graded in).

    A fresh mkdtemp has no siblings, no repo above it, and no project
    configuration to discover. The blinded inputs are still archived under
    the cell's artifacts for the record -- see archive_blind_inputs.
    """
    return Path(tempfile.mkdtemp(prefix="bench-blind-"))


def build_blind_dir(cell: dict, story: dict, base: Path) -> Path:
    target = base / cell_hash(cell)
    target.mkdir(parents=True, exist_ok=True)

    diff = subprocess.run(
        ["git", "-C", cell["worktree"], "diff", cell["base_sha"], "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    numbered_acs, _ = number_acceptance_criteria(story["acs"])
    (target / "diff.patch").write_text(filter_diff(diff))
    (target / "acs.md").write_text(numbered_acs)
    tests = Path(cell["artifacts"]) / "tests.txt"
    (target / "tests.txt").write_text(tests.read_text() if tests.exists() else "not run")
    return target


def archive_blind_inputs(cell: dict, blind_dir: Path) -> Path:
    """Copy the blinded inputs under the cell's artifacts, for the record.

    The grader runs from the isolated temp dir; this copy exists so the
    exact inputs a paid grader call saw remain auditable after the temp dir
    is gone. It is written AFTER the grader directory is built and is never
    the grader's cwd.
    """
    target = Path(cell["artifacts"]) / "blind" / blind_dir.name
    if target.exists():
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(str(blind_dir), str(target))
    return target


def run_grader(blind_dir: Path, acs: str, ac_ids: Optional[List[str]] = None) -> dict:
    diff_text = (blind_dir / "diff.patch").read_text()
    tests_text = (blind_dir / "tests.txt").read_text()
    proc = subprocess.run(
        ["claude", "--print", "--output-format", "json"],
        cwd=str(blind_dir),
        input=grader_prompt(acs, diff_text, tests_text, ac_ids or []),
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
    grader_fn: Callable = run_grader,
    ac_ids: Optional[List[str]] = None,
) -> dict:
    """Run `count` graders, retrying a failing grader once before giving up
    on it. Each grader call costs real money, so one flaky call must not
    throw away the others: this proceeds once a majority of graders produced
    a verdict, and raises only if fewer than a majority succeeded.

    A verdict is validated here, inside the retry loop, against the
    harness-assigned `ac_ids`. Malformed shape and unknown ids are both
    treated as retryable grader failures -- so the offending grader is
    re-requested once and, if it fails again, only IT is discarded. That is
    the whole point: one grader returning `"acs": "none"` used to throw a
    TypeError out of the reduce step and discard all three paid calls.
    """
    ac_ids = ac_ids or []
    verdicts: List[dict] = []
    failures: List[str] = []
    for _ in range(count):
        verdict = None
        last_error = None
        for _attempt in range(2):  # initial try + one retry
            try:
                verdict = validate_verdict(grader_fn(blind_dir, acs, ac_ids), ac_ids)
                break
            except Exception as exc:  # noqa: BLE001 - any grader failure is retryable
                last_error = str(exc)
                verdict = None
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


def reduce_verdicts(verdicts: List[dict], ac_ids: Optional[List[str]] = None) -> dict:
    """Reduce independent grader verdicts to one verdict per AC.

    Majority is relative to the votes actually cast for that AC, not to
    len(verdicts): a grader that failed validation contributes nothing, and
    an AC it would have voted on must not be punished for its absence. An
    exact tie resolves to not-met — the burden of proof for "this AC is
    satisfied" sits with the evidence, not the vote count.

    When `ac_ids` is supplied, EVERY id appears in the result whether or not
    any grader mentioned it — an unmentioned criterion is not-met with zero
    votes. That is what makes acs_met/acs_total comparable across rows: the
    denominator is the ticket's criterion count, fixed by the harness,
    identical for every approach.

    Entries are read defensively (`.get`, not `[]`) even though
    validate_verdict has already normalised them, because this function is
    also reachable with hand-built or historical verdict data.
    """
    acs: Dict[str, dict] = {}
    for ac_id in ac_ids or []:
        acs[ac_id] = {"votes": [], "evidence": []}

    for verdict in verdicts:
        items = verdict.get("acs")
        if not isinstance(items, list):
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            ac_id = item.get("id")
            if not isinstance(ac_id, str):
                continue
            acs.setdefault(ac_id, {"votes": [], "evidence": []})
            acs[ac_id]["votes"].append(bool(item.get("met")))
            if item.get("evidence"):
                acs[ac_id]["evidence"].append(item["evidence"])

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

    counts = [
        len(v.get("findings")) if isinstance(v.get("findings"), list) else 0
        for v in verdicts
    ]
    fix_items = []
    for v in verdicts:
        try:
            fix_items.append(int(v.get("first_fix_round_items") or 0))
        except (TypeError, ValueError):
            fix_items.append(0)
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

    numbered_acs, ac_ids = number_acceptance_criteria(story["acs"])

    # Built in an isolated temp root outside every repository, then archived
    # under the cell's artifacts. The grader only ever sees the temp copy.
    blind_dir = build_blind_dir(cell, story, blind_base_dir(cell))
    archived = archive_blind_inputs(cell, blind_dir)

    result = collect_verdicts(
        blind_dir, numbered_acs, args.graders, ac_ids=ac_ids
    )
    reduced = reduce_verdicts(result["verdicts"], ac_ids=ac_ids)
    reduced["blind_dir"] = str(blind_dir)
    reduced["blind_inputs_archived_to"] = str(archived)
    reduced["ac_ids"] = ac_ids
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
