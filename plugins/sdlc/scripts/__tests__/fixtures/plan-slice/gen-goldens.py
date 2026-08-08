#!/usr/bin/env python3
"""gen-goldens.py — NA-81. One-shot golden generator for plan-slice.sh's fixture goldens and the
real-corpus expectation file.

Deliberately NOT plan-slice.sh: it reimplements the grammar independently, in Python, so the test
suite compares two independent implementations rather than comparing the change to itself (the
NA-93 A3 lesson). Author-run, not CI-run; its OUTPUT is committed and CI only reads that output.

Python 3.9 stdlib only — no `match`, no PEP 604 runtime unions.

Run this only against a CLEAN docs/superpowers/plans/ tree — sha comes from `git rev-parse HEAD`,
bytes come from the working tree, and a dirty tree makes those two disagree. main() enforces this
with a refusal, not just this note.

Provenance note: the .slice / .checklist golden files are compared BYTE-FOR-BYTE against
plan-slice.sh's real stdout-named file (cmp -s), so they carry no header of their own — a header
would make that comparison fail by construction. Provenance (# sourceSha / # sourceBytes) is
recorded on `corpus-expectation.tsv` only, which is read as structured rows, never byte-compared
to a script's raw output. plan-slice.test.sh's provenance check (G-1 Step 7) reads it from there.
"""
import pathlib
import re
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
PLANS_DIR = HERE / "plans"
GOLDENS_DIR = HERE / "goldens"
REPO_ROOT = HERE.parents[5]
CORPUS_DIR = REPO_ROOT / "docs" / "superpowers" / "plans"

AGENT_SET = [
    "database-administrator", "platform-engineer", "ai-enablement-engineer",
    "sync-engineer", "web-engineer", "mobile-engineer", "knowledge-engineer",
]

PHASE_RE = re.compile(r'^##[ ]+Phase($|[^A-Za-z])')
SECTION_END_RE = re.compile(r'^##[^#]')
TASK_RE = re.compile(r'^[ \t]*[-*] \[[ xX]\][ \t]')
FENCE_RE = re.compile(r'^(```|~~~)')


def owners_of(line):
    return [tok for tok in AGENT_SET if tok in line]


def scan(text):
    """Fence-aware single pass over `text`. Returns (phases, doc_tasks, sections):
    phases    -- count of phase headings naming >=1 AGENT_SET token
    doc_tasks -- count of TASK_LINE in the whole doc, fence-aware
    sections  -- list of {"owners": [...], "lines": [...], "tasks": n}, in document order, one
                 per matched phase heading. "lines" includes the heading line itself and any
                 fenced content verbatim; "tasks" counts only non-fenced task lines within it.
    """
    lines = text.splitlines()
    in_fence = False
    open_section = None
    phases = 0
    doc_tasks = 0
    sections = []
    for line in lines:
        trimmed = line.lstrip()
        if FENCE_RE.match(trimmed):
            if open_section is not None:
                open_section["lines"].append(line)
            in_fence = not in_fence
            continue
        if in_fence:
            if open_section is not None:
                open_section["lines"].append(line)
            continue
        is_heading2 = bool(SECTION_END_RE.match(line))
        owners = owners_of(line) if PHASE_RE.match(line) else []
        if is_heading2:
            open_section = None
        if owners:
            phases += 1
            open_section = {"owners": owners, "lines": [line], "tasks": 0}
            sections.append(open_section)
            continue
        is_task = bool(TASK_RE.match(line))
        if is_task:
            doc_tasks += 1
        if open_section is not None:
            open_section["lines"].append(line)
            if is_task:
                open_section["tasks"] += 1
    return phases, doc_tasks, sections


def slice_for(sections, agent):
    matched = [s for s in sections if agent in s["owners"]]
    if not matched:
        return None
    parts = ["\n".join(s["lines"]) for s in matched]
    return "\n\n".join(parts) + "\n"


def checklist_for(text):
    lines = text.splitlines()
    in_fence = False
    out = []
    for line in lines:
        trimmed = line.lstrip()
        if FENCE_RE.match(trimmed):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if TASK_RE.match(line):
            out.append(line)
    if not out:
        return None
    return "\n".join(out) + "\n"


def git_sha():
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=str(REPO_ROOT)).decode().strip()


def assert_clean_corpus_tree():
    """sourceSha is measured from HEAD but sourceBytes is measured from the WORKING TREE — the two
    only agree when CORPUS_DIR has no uncommitted changes. Running this against a dirty corpus tree
    silently stamps a sha that cannot reproduce the recorded bytes (the NA-101 review-round bug:
    sourceSha=<pre-edit HEAD>, NA-101.md=<post-edit, uncommitted bytes>). Refuse rather than warn —
    a warning is easy to miss in scrollback; a refusal cannot be.
    """
    out = subprocess.check_output(
        ["git", "status", "--porcelain", "--", str(CORPUS_DIR)], cwd=str(REPO_ROOT)
    ).decode()
    if out.strip():
        raise SystemExit(
            "gen-goldens.py: refusing to run — {} has uncommitted changes:\n{}\n"
            "sourceSha (git rev-parse HEAD) and sourceBytes (working-tree read) would be measured "
            "from DIFFERENT states. Commit or stash the changes under docs/superpowers/plans/, "
            "then re-run against a clean tree.".format(CORPUS_DIR, out.rstrip("\n"))
        )


def main():
    assert_clean_corpus_tree()
    sha = git_sha()
    GOLDENS_DIR.mkdir(parents=True, exist_ok=True)

    cases = [
        ("bracket.md", "platform-engineer"),
        ("bracket.md", "ai-enablement-engineer"),
        ("backtick.md", "platform-engineer"),
        ("backtick.md", "ai-enablement-engineer"),
        ("two-phase.md", "ai-enablement-engineer"),
        ("two-phase.md", "platform-engineer"),
        ("fenced.md", "web-engineer"),
    ]
    for fname, agent in cases:
        fpath = PLANS_DIR / fname
        text = fpath.read_text()
        _phases, _doc_tasks, sections = scan(text)
        sl = slice_for(sections, agent)
        if sl is None:
            continue
        golden_name = "{}.{}.slice".format(fpath.stem, agent)
        (GOLDENS_DIR / golden_name).write_text(sl)

    bracket_text = (PLANS_DIR / "bracket.md").read_text()
    cl = checklist_for(bracket_text)
    (GOLDENS_DIR / "bracket.checklist").write_text(cl)

    files = sorted(CORPUS_DIR.glob("*.md"))
    rows = []
    source_bytes_parts = []
    for f in files:
        text = f.read_text()
        source_bytes_parts.append("{}={}".format(f.name, len(text.encode("utf-8"))))
        phases, doc_tasks, sections = scan(text)
        matched_sections = [s for s in sections if "ai-enablement-engineer" in s["owners"]]
        grammar = "matched" if phases > 0 else "unmatched"
        if matched_sections:
            tasks = sum(s["tasks"] for s in matched_sections)
        else:
            tasks = doc_tasks
        rows.append((f.name, grammar, phases, tasks))

    assert len(files) == len(rows), "row count must equal file count"
    matched_n = sum(1 for r in rows if r[1] == "matched")
    unmatched_n = sum(1 for r in rows if r[1] == "unmatched")

    exp_path = HERE / "corpus-expectation.tsv"
    with exp_path.open("w") as fh:
        fh.write("# sourceSha: {}\n".format(sha))
        fh.write("# sourceBytes: {}\n".format(" ".join(source_bytes_parts)))
        fh.write("# files: {}   # matched: {}   # unmatched: {}\n".format(len(files), matched_n, unmatched_n))
        for name, grammar, phases, tasks in rows:
            fh.write("{}\t{}\t{}\t{}\n".format(name, grammar, phases, tasks))

    print("files={} matched={} unmatched={}".format(len(files), matched_n, unmatched_n))


if __name__ == "__main__":
    main()
