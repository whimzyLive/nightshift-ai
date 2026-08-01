#!/usr/bin/env python3
"""
loop-decision.py — NA-93 loop-decide.sh golden extractor (workstream H, Epic NA-76).

H moves the sdlc:loop probe-and-decide body (commands/loop.md Step 3+4, refs/loop-modes.md
CI-1+CI-2) into a deterministic script, plugins/sdlc/scripts/loop-decide.sh. This tool proves
the two markdown decision tables and the shipped script agree on all 1,458 enumerable cases,
and separately reports how the real historical corpus distributes across the seven Copilot
rules (1, 2a, 2b, 3, 4, 5, 6, 7 — the in-session table CI-a..CI-f is not replayed; see
"Why --replay only classifies Copilot-shaped lines" below).

Three modes, one CLI, mutually exclusive:

    --extract <loop.md> <loop-modes.md> [--json]
        Parses both markdown decision tables PER FIELD (never as a whole-cell string match —
        that shape would echo a rule id back and extract identically from a perturbed table,
        which is exactly what F-1 exists to catch). Emits a list of Rule dicts:
        {"id": str, "path": "copilot"|"in-session", "conditions": [...], "decision": str}.

    --enumerate --golden <path> [--extract-from <loop.md> <loop-modes.md>] [--json]
        Generates all 1,458 domain cases (below) and, when --golden is given, writes them to
        <path> alongside sourceSha (git rev-parse HEAD) and sourceBytes (measured by THIS tool
        from the files it read, never passed in) — the golden's provenance, asserted
        mechanically by plugins/sdlc/scripts/__tests__/loop-decide.test.sh (amendment A3).

    --replay <label> (<transcript.jsonl>... | --corpus-list <file>) [--json]
        Scans the three-tier transcript corpus (below) for real `loop-status:` lines and
        classifies each one via the COMMITTED GOLDEN's cases[] — a direct lookup, not a fresh
        markdown parse. This is deliberate: Phase 2 rewrites commands/loop.md and
        refs/loop-modes.md to a script call, so by the time Phase 3 runs --replay against the
        real corpus, the markdown files no longer contain a decision table to parse. The golden
        (extracted in Phase 1, before any H edit) is the only durable classification source that
        survives the rewrite, and it is what makes H-Gate-3 runnable at all in Phase 3.

The decision domain (verbatim, spec "The decision domain — why AC-2 is provable, not sampled").
Only the 0 / 1 / >1 distinction is load-bearing for the count fields, so the domain is finite:

    copilot    := rh∈{0,1} × cr∈{0,1} × cp∈{0,1} × ra∈{0,1} × un∈{0,1,2} × pend∈{0,1,2}
                  × fail∈{0,1,2} × pass∈{0,1,2}                      = 2^4 · 3^4 = 1,296
    in-session := rh∈{0,1} × rc∈{0,1,'-'} × un∈{0,1,2} × pend∈{0,1,2} × fail∈{0,1,2} = 162
    total      := 1,458 cases

Field names, exactly as they appear in the two source tables and in pr-loop-status.sh's own
stdout contract:

    copilot    (8): copilot-reviewed-head, copilot-changes-requested, copilot-pending,
                     unresolved-copilot, checks-pending, checks-failing, checks-passing,
                     copilot-reviewed-any
    in-session (5): reviewed-head, review-clean, unresolved, checks-pending, checks-failing

`review-clean='-'` is a LEGITIMATE value, not a parse failure (CI-1 sets it when the review
marker is absent or half-written). No rule in the in-session table ever compares review-clean
to anything but the literals 0 and 1, so the generic comparator below (`compare()`) already
does the right thing without a special case: '-' never equals 0 or 1, so every rule that tests
review-clean fails for it, and (reviewed-head=1, review-clean='-') falls through to CI-f
exactly as the spec requires. This is F-11's mechanism, stated here so nobody "fixes" it.

The bucketing rule (verbatim — used ONLY by --replay, never by --enumerate, which already
generates directly over the bucket domain {0,1,2}):

    bucket(v) := v            IF v ∈ {0, 1}
    bucket(v) := 2            OTHERWISE   (collapses any count ≥ 2, e.g. un=3, un=4, to the
                                            domain's un=2 bucket)

The corpus rule (verbatim — mirrors work-placement.py / read-bounding.py / context-residency.py,
used only by --replay):

    project := ~/.claude/projects/<encoded-repo-path>
    T1 top-level := <project>/*.jsonl
    T2 subagent  := <project>/*/subagents/agent-*.jsonl
    T3 wf agent  := <project>/*/subagents/workflows/wf_*/agent-*.jsonl
    a root that is a directory  -> T1 := root.glob("*.jsonl")            (non-recursive)
                                    T2+T3 := root.rglob("agent-*.jsonl")  (recursive — REQUIRED;
                                             T3 is 890 of 1,452 subagent transcripts and a
                                             one-level glob misses every one of them — NA-90's
                                             shipped bug)
    a root that is a .jsonl file -> used as-is
    snapshot := any `loop-status:` line found in any turn's content, matched by the exact
                8-field shape pr-loop-status.sh:130 emits

Path lists are built with Python `pathlib`, never parsed `ls` — the local rtk shell hook
rewrites and size-annotates `ls` output, silently corrupting a naive corpus list.

Why --replay only classifies Copilot-shaped lines. `refs/loop-modes.md` CI-1 calls
pr-loop-status.sh "ONLY for its checks-* fields" but that script always prints the full
8-field `loop-status:` line regardless of caller — so every real `loop-status:` snapshot in
this repo's corpus is Copilot-shaped even though `Review agent: claude-inline` is configured.
This matches the spec's own real-corpus table (9 distinct 8-tuples, all in the (rh, cr, cp,
un, pend, fail, pass, ra) shape). The in-session path's own CI-1 progress print (`reviewed-
head=... review-clean=...`) carries no `loop-status:` prefix and is not scanned here.

`observed.rulesWithZeroEvidence` — every one of the 8 Copilot rule ids (1, 2a, 2b, 3, 4, 5, 6,
7) that the resolved corpus never selected. At the real corpus this is exactly ["1","5","6","7"]
(186 snapshots, 9 distinct tuples, all mapping to 2a/2b/3/4) — enumeration proves the script
matches the table; it does NOT prove the table was ever right for the four unexercised rules.

NA-88 D11 — this instrument and its fixtures are authored by the same story that ships the
script it will later validate. A PASS on loop-decision.test.sh proves the tool does what its
author designed; it proves NOTHING about whether any real PR has exercised rules 1, 5, 6, or 7.
This is a smoke test, never a gate on the decision table's own correctness.

Analyser tools are read-only: this script never writes to the repo, to ~/.claude/, or to any
artifact it scans, except the golden file explicitly named by --golden.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

COPILOT_FIELDS = [
    "copilot-reviewed-head",
    "copilot-changes-requested",
    "copilot-pending",
    "unresolved-copilot",
    "checks-pending",
    "checks-failing",
    "checks-passing",
    "copilot-reviewed-any",
]
IN_SESSION_FIELDS = [
    "reviewed-head",
    "review-clean",
    "unresolved",
    "checks-pending",
    "checks-failing",
]
COUNT_FIELDS_COPILOT = {"unresolved-copilot", "checks-pending", "checks-failing", "checks-passing"}
COPILOT_RULE_IDS = ["1", "2a", "2b", "3", "4", "5", "6", "7"]
IN_SESSION_RULE_IDS = ["CI-a", "CI-b", "CI-c", "CI-c2", "CI-d", "CI-e", "CI-f"]

# Rule -> DECISION mapping, verbatim from the plan's "Rule -> DECISION mapping" table. A fixed
# 16-row map, not inferred from the tables' prose columns.
RULE_TO_DECISION = {
    "1": "wait",
    "2a": "wait",
    "2b": "wait",
    "3": "fix",
    "4": "clean",
    "5": "wait",
    "6": "halt",
    "7": "halt",
    "CI-a": "wait",
    "CI-b": "review",
    "CI-c": "fix",
    "CI-c2": "halt",
    "CI-d": "clean",
    "CI-e": "halt",
    "CI-f": "halt",
}

TABLE_HEADER_RE = re.compile(r"^\|\s*#\s*\|\s*Condition\s*\|\s*Action\s*\|\s*$")
COMPARISON_RE = re.compile(r"^([A-Za-z][A-Za-z0-9-]*)\s*(==|!=|>=|<=|>|<)\s*(-?\d+)$")
LOOP_STATUS_RE = re.compile(
    r"loop-status:\s*copilot-reviewed-head=(-?\d+)\s+copilot-changes-requested=(-?\d+)\s+"
    r"copilot-pending=(-?\d+)\s+unresolved-copilot=(-?\d+)\s+checks-pending=(-?\d+)\s+"
    r"checks-failing=(-?\d+)\s+checks-passing=(-?\d+)\s+copilot-reviewed-any=(-?\d+)"
)

DEFAULT_LOOP_MD = "plugins/sdlc/commands/loop.md"
DEFAULT_MODES_MD = "plugins/sdlc/refs/loop-modes.md"
GOLDEN_KEY_LOOP_MD = "plugins/sdlc/commands/loop.md"
GOLDEN_KEY_MODES_MD = "plugins/sdlc/refs/loop-modes.md"


def bucket(v):
    return v if v in (0, 1) else 2


def split_row(line):
    parts = re.split(r"(?<!\\)\|", line)
    parts = [p.strip() for p in parts]
    if parts and parts[0] == "":
        parts = parts[1:]
    if parts and parts[-1] == "":
        parts = parts[:-1]
    return parts


def find_table_rows(text):
    rows = []
    in_table = False
    seen_sep = False
    for line in text.splitlines():
        stripped = line.strip()
        if not in_table:
            if TABLE_HEADER_RE.match(stripped):
                in_table = True
            continue
        if not seen_sep:
            seen_sep = True
            continue
        if not stripped.startswith("|"):
            break
        cells = split_row(line)
        if len(cells) < 3:
            break
        rows.append((cells[0].strip(), cells[1]))
    return rows


def parse_comparison(text, valid_fields, warnings):
    text = text.strip()
    m = COMPARISON_RE.match(text)
    if not m:
        warnings.append("unparseable comparison: %r" % text)
        return None
    field, op, value = m.group(1), m.group(2), int(m.group(3))
    if field not in valid_fields:
        warnings.append("field %r not in domain %r" % (field, valid_fields))
        return None
    return {"field": field, "op": op, "value": value}


def parse_condition_cell(cell_raw, valid_fields, warnings):
    m = re.search(r"`([^`]+)`", cell_raw)
    if m:
        content = m.group(1)
    elif cell_raw.strip().startswith("_("):
        return []
    else:
        warnings.append("no backtick-delimited condition and not catch-all: %r" % cell_raw)
        return None
    content = content.replace(r"\|", "|")
    clauses = []
    for part in re.split(r"\s*&&\s*", content.strip()):
        part = part.strip()
        if part.startswith("(") and part.endswith(")"):
            inner = part[1:-1]
            ors = [parse_comparison(p, valid_fields, warnings) for p in re.split(r"\s*\|\|\s*", inner)]
            if any(o is None for o in ors):
                return None
            clauses.append({"or": ors})
        else:
            c = parse_comparison(part, valid_fields, warnings)
            if c is None:
                return None
            clauses.append(c)
    return clauses


def extract_tables(loop_md_path, loop_modes_md_path):
    warnings = []
    loop_text = Path(loop_md_path).read_text(encoding="utf-8")
    modes_text = Path(loop_modes_md_path).read_text(encoding="utf-8")

    rules = []
    copilot_count = 0
    for rid, cond in find_table_rows(loop_text):
        clauses = parse_condition_cell(cond, COPILOT_FIELDS, warnings)
        if clauses is None:
            continue
        copilot_count += 1
        rules.append({"id": rid, "path": "copilot", "conditions": clauses, "decision": RULE_TO_DECISION.get(rid, "unresolvable")})

    in_session_count = 0
    for rid, cond in find_table_rows(modes_text):
        clauses = parse_condition_cell(cond, IN_SESSION_FIELDS, warnings)
        if clauses is None:
            continue
        in_session_count += 1
        rules.append({"id": rid, "path": "in-session", "conditions": clauses, "decision": RULE_TO_DECISION.get(rid, "unresolvable")})

    for w in warnings:
        print("loop-decision: WARNING — %s" % w, file=sys.stderr)

    if copilot_count != 8:
        print(
            "loop-decision: FATAL — expected 8 copilot rules (1,2a,2b,3,4,5,6,7), got %d — "
            "extractor is misparsing, STOP" % copilot_count,
            file=sys.stderr,
        )
        sys.exit(1)
    if in_session_count != 7:
        print(
            "loop-decision: FATAL — expected 7 in-session rules (CI-a..CI-f), got %d — "
            "extractor is misparsing, STOP" % in_session_count,
            file=sys.stderr,
        )
        sys.exit(1)
    return rules


def compare(op, actual, literal):
    if isinstance(actual, str):
        if op == "==":
            return False
        if op == "!=":
            return True
        return False
    if op == "==":
        return actual == literal
    if op == "!=":
        return actual != literal
    if op == ">":
        return actual > literal
    if op == "<":
        return actual < literal
    if op == ">=":
        return actual >= literal
    if op == "<=":
        return actual <= literal
    return False


def eval_clause(clause, fields):
    if "or" in clause:
        return any(compare(c["op"], fields[c["field"]], c["value"]) for c in clause["or"])
    return compare(clause["op"], fields[clause["field"]], clause["value"])


def eval_rule(rule, fields):
    return all(eval_clause(c, fields) for c in rule["conditions"])


def decide(rules, path, fields):
    for r in rules:
        if r["path"] != path:
            continue
        if eval_rule(r, fields):
            return r["id"], r["decision"]
    return "unresolvable", "wait"


def enumerate_domain(rules):
    cases = []
    for rh in (0, 1):
        for cr in (0, 1):
            for cp in (0, 1):
                for ra in (0, 1):
                    for un in (0, 1, 2):
                        for pend in (0, 1, 2):
                            for fail in (0, 1, 2):
                                for pas in (0, 1, 2):
                                    fields = {
                                        "copilot-reviewed-head": rh,
                                        "copilot-changes-requested": cr,
                                        "copilot-pending": cp,
                                        "copilot-reviewed-any": ra,
                                        "unresolved-copilot": un,
                                        "checks-pending": pend,
                                        "checks-failing": fail,
                                        "checks-passing": pas,
                                    }
                                    rid, decision = decide(rules, "copilot", fields)
                                    cases.append({"path": "copilot", "fields": fields, "rule": rid, "decision": decision})
    for rh in (0, 1):
        for rc in (0, 1, "-"):
            for un in (0, 1, 2):
                for pend in (0, 1, 2):
                    for fail in (0, 1, 2):
                        fields = {
                            "reviewed-head": rh,
                            "review-clean": rc,
                            "unresolved": un,
                            "checks-pending": pend,
                            "checks-failing": fail,
                        }
                        rid, decision = decide(rules, "in-session", fields)
                        cases.append({"path": "in-session", "fields": fields, "rule": rid, "decision": decision})
    return cases


def git_head_sha():
    out = subprocess.check_output(["git", "rev-parse", "HEAD"], stderr=subprocess.DEVNULL)
    return out.decode().strip()


def read_corpus_list(list_path):
    base = os.path.dirname(os.path.abspath(list_path))
    entries = []
    with open(list_path, encoding="utf-8") as f:
        for raw in f:
            entry = raw.strip()
            if not entry or entry.startswith("#"):
                continue
            entry = os.path.expanduser(entry)
            if not os.path.isabs(entry):
                entry = os.path.join(base, entry)
            entries.append(entry)
    return entries


def resolve_corpus(raw_entries):
    t1_files, subagent_files, missing = [], [], []
    for raw in raw_entries:
        path = os.path.expanduser(raw)
        if os.path.isdir(path):
            root = Path(path)
            for f in sorted(root.glob("*.jsonl")):
                t1_files.append(str(f))
            for f in sorted(root.rglob("agent-*.jsonl")):
                subagent_files.append(str(f))
        elif os.path.isfile(path):
            normalized = path.replace(os.sep, "/")
            if "/subagents/" in normalized:
                subagent_files.append(path)
            else:
                t1_files.append(path)
        else:
            missing.append(os.path.abspath(path))
    return t1_files, subagent_files, missing


def iter_texts(record):
    message = record.get("message") or {}
    content = message.get("content")
    if isinstance(content, str):
        yield content
        return
    if not isinstance(content, list):
        return
    for item in content:
        if not isinstance(item, dict):
            continue
        t = item.get("text")
        if isinstance(t, str):
            yield t
        c2 = item.get("content")
        if isinstance(c2, str):
            yield c2
        elif isinstance(c2, list):
            for sub in c2:
                if isinstance(sub, dict) and isinstance(sub.get("text"), str):
                    yield sub["text"]


def load_golden(golden_path=None):
    if golden_path is None:
        golden_path = str(Path(__file__).resolve().parent / "__tests__" / "fixtures" / "loop-decision-golden.json")
    with open(golden_path, encoding="utf-8") as f:
        return json.load(f)


def build_lookup(golden):
    lookup = {}
    for c in golden["cases"]:
        if c["path"] != "copilot":
            continue
        key = tuple(sorted(c["fields"].items()))
        lookup[key] = c["rule"]
    return lookup


def replay_corpus(resolved_paths, lookup):
    snapshots = 0
    distinct_raw = set()
    by_rule = {rid: 0 for rid in COPILOT_RULE_IDS}
    skipped = 0
    for path in resolved_paths:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except (json.JSONDecodeError, ValueError):
                    skipped += 1
                    continue
                for text in iter_texts(record):
                    for m in LOOP_STATUS_RE.finditer(text):
                        raw = {
                            "copilot-reviewed-head": int(m.group(1)),
                            "copilot-changes-requested": int(m.group(2)),
                            "copilot-pending": int(m.group(3)),
                            "unresolved-copilot": int(m.group(4)),
                            "checks-pending": int(m.group(5)),
                            "checks-failing": int(m.group(6)),
                            "checks-passing": int(m.group(7)),
                            "copilot-reviewed-any": int(m.group(8)),
                        }
                        snapshots += 1
                        distinct_raw.add(tuple(sorted(raw.items())))
                        bucketed = {
                            k: (bucket(v) if k in COUNT_FIELDS_COPILOT else v) for k, v in raw.items()
                        }
                        key = tuple(sorted(bucketed.items()))
                        rid = lookup.get(key, "unresolvable")
                        by_rule[rid] = by_rule.get(rid, 0) + 1
    rules_with_zero = [rid for rid in COPILOT_RULE_IDS if by_rule.get(rid, 0) == 0]
    observed = {
        "snapshots": snapshots,
        "distinct": len(distinct_raw),
        "byRule": by_rule,
        "rulesWithZeroEvidence": rules_with_zero,
    }
    return observed, skipped


def usage():
    print(
        "usage: loop-decision.py --extract <loop.md> <loop-modes.md> [--json]\n"
        "       loop-decision.py --enumerate --golden <path> [--extract-from <loop.md> <loop-modes.md>] [--json]\n"
        "       loop-decision.py --replay <label> (<transcript.jsonl>... | --corpus-list <file>) [--json]",
        file=sys.stderr,
    )


def cmd_extract(rest):
    json_out = "--json" in rest
    positional = [a for a in rest if a != "--json"]
    if len(positional) != 2:
        usage()
        return 2
    loop_md, modes_md = positional
    rules = extract_tables(loop_md, modes_md)
    if json_out:
        print(json.dumps({"rules": rules}, indent=2))
    else:
        for r in rules:
            print("%-6s %-11s decision=%-6s conditions=%s" % (r["id"], r["path"], r["decision"], json.dumps(r["conditions"])))
    return 0


def cmd_enumerate(rest):
    golden_path = None
    loop_md = DEFAULT_LOOP_MD
    modes_md = DEFAULT_MODES_MD
    json_out = False
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--golden":
            i += 1
            golden_path = rest[i]
        elif a == "--extract-from":
            loop_md = rest[i + 1]
            modes_md = rest[i + 2]
            i += 2
        elif a == "--json":
            json_out = True
        else:
            print("loop-decision: unknown --enumerate argument %r" % a, file=sys.stderr)
            usage()
            return 2
        i += 1

    rules = extract_tables(loop_md, modes_md)
    cases = enumerate_domain(rules)
    if len(cases) != 1458:
        print("loop-decision: FATAL — expected 1458 cases, got %d" % len(cases), file=sys.stderr)
        return 1
    domain = {
        "copilotCases": sum(1 for c in cases if c["path"] == "copilot"),
        "inSessionCases": sum(1 for c in cases if c["path"] == "in-session"),
        "totalCases": len(cases),
    }
    result = {"domain": domain, "cases": cases}

    if golden_path:
        try:
            sha = git_head_sha()
        except Exception as exc:
            print("loop-decision: FATAL — could not resolve git HEAD sha: %s" % exc, file=sys.stderr)
            return 1
        result = {
            "sourceSha": sha,
            "sourceBytes": {
                GOLDEN_KEY_LOOP_MD: os.path.getsize(loop_md),
                GOLDEN_KEY_MODES_MD: os.path.getsize(modes_md),
            },
            "domain": domain,
            "cases": cases,
        }
        with open(golden_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
            f.write("\n")

    if json_out:
        print(json.dumps(result, indent=2))
    else:
        print("domain: copilot=%d in-session=%d total=%d" % (domain["copilotCases"], domain["inSessionCases"], domain["totalCases"]))
        if golden_path:
            print("golden written: %s (sourceSha=%s)" % (golden_path, result["sourceSha"]))
    return 0


def cmd_replay(rest):
    label = None
    raw_paths = []
    corpus_list = None
    json_out = False
    positional = []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--corpus-list":
            i += 1
            corpus_list = rest[i]
        elif a == "--json":
            json_out = True
        else:
            positional.append(a)
        i += 1
    if not positional:
        print("loop-decision: missing <label>", file=sys.stderr)
        usage()
        return 2
    label = positional[0]
    raw_paths = positional[1:]

    raw_entries = read_corpus_list(corpus_list) if corpus_list else raw_paths
    if not raw_entries:
        usage()
        return 2

    t1_files, subagent_files, missing = resolve_corpus(raw_entries)
    if not t1_files and not subagent_files:
        attempted = missing or raw_entries
        print(
            "loop-decision: no transcript files found; resolved path(s) tried:\n  " + "\n  ".join(attempted),
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    if missing:
        print(
            "loop-decision: WARNING — %d of %d corpus roots did not resolve to a readable "
            "file or directory and were dropped:\n  " % (len(missing), len(raw_entries)) + "\n  ".join(missing),
            file=sys.stderr,
        )
        if corpus_list:
            exit_code = 1

    resolved_paths = t1_files + subagent_files
    has_t3 = any("/subagents/workflows/" in p.replace(os.sep, "/") for p in subagent_files)
    if not has_t3:
        print(
            "loop-decision: WARNING — 0 of %d transcripts matched "
            "*/subagents/workflows/wf_*/agent-*.jsonl; a non-recursive glob misses 890 of "
            "1,452 subagent transcripts (NA-90's shipped bug). Verify the corpus root."
            % len(resolved_paths),
            file=sys.stderr,
        )

    try:
        golden = load_golden()
    except OSError as exc:
        print("loop-decision: FATAL — could not load the golden fixture: %s" % exc, file=sys.stderr)
        return 1
    lookup = build_lookup(golden)
    observed, skipped = replay_corpus(resolved_paths, lookup)

    report = {
        "label": label,
        "corpus": {
            "topLevelTranscripts": len(t1_files),
            "subagentTranscripts": len(subagent_files),
        },
        "domain": golden["domain"],
        "observed": observed,
        "skippedLines": skipped,
        "missingCorpusPaths": len(missing),
    }

    if json_out:
        print(json.dumps(report, indent=2))
    else:
        print("\n### %s" % label)
        print("corpus: %d top-level / %d subagent transcripts" % (report["corpus"]["topLevelTranscripts"], report["corpus"]["subagentTranscripts"]))
        print("observed.snapshots %d  distinct %d" % (observed["snapshots"], observed["distinct"]))
        for rid in COPILOT_RULE_IDS:
            print("  rule %-4s %d" % (rid, observed["byRule"].get(rid, 0)))
        print("rulesWithZeroEvidence %s" % observed["rulesWithZeroEvidence"])
        print("skippedLines %d" % skipped)
        print(
            "\nNOTE (NA-88 D11, self-confirming): a green replay proves the corpus classifies "
            "against the golden as expected; it proves nothing about whether rules 1, 5, 6, 7 "
            "are correct — no real PR has ever exercised them."
        )
    return exit_code


def main(argv):
    if not argv:
        usage()
        return 2
    mode, rest = argv[0], argv[1:]
    if mode == "--extract":
        return cmd_extract(rest)
    if mode == "--enumerate":
        return cmd_enumerate(rest)
    if mode == "--replay":
        return cmd_replay(rest)
    usage()
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
