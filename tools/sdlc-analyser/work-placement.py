#!/usr/bin/env python3
"""
work-placement.py — NA-92 offload-placement analyser (workstream G, Epic NA-76).

Measures, per unit of work (G1/G2/G3), what share of that unit's direct-execution
tool-result bytes landed in a subagent rather than the orchestrator, and whether the
unit's dispatch return exceeded its stated round-trip cap — the instrument NA-92's
AC-2/AC-3/AC-4 pilot gate is scored against.

The corpus rule (verbatim — mirrors read-bounding.py / context-residency.py):

    origin := subagent   IF the transcript path contains "/subagents/"
    origin := orchestrator OTHERWISE

    project := ~/.claude/projects/<encoded-repo-path>
    T1 top-level := <project>/*.jsonl
    T2 subagent  := <project>/*/subagents/agent-*.jsonl
    T3 wf agent  := <project>/*/subagents/workflows/wf_*/agent-*.jsonl

Every corpus-list / positional entry is treated as a ROOT (verbatim from the plan):

    a root that is a directory  -> T1 := root.glob("*.jsonl")  (non-recursive, direct children)
                                    T2+T3 := root.rglob("agent-*.jsonl")  (recursive — REQUIRED,
                                             never a non-recursive glob: T3
                                             (*/subagents/workflows/wf_*/agent-*.jsonl) is 890 of
                                             1,447 subagent transcripts and a one-level glob misses
                                             every one of them — this is NA-90's shipped bug)
    a root that is a .jsonl file -> used as-is, tiered by origin_of(path)

Path lists are built with Python `pathlib`, never parsed `ls` — the local rtk shell hook
rewrites and size-annotates `ls` output, silently corrupting a naive corpus list.

The unit-attribution rule (verbatim). Attribution counts only DIRECT-EXECUTION tool
results — Bash, Read, Grep, Glob. `Agent` and `SendMessage` returns are excluded from
this count on purpose: that traffic is already inside a subagent, and counting it would
inflate G's own claim.

    a DIRECT call    := a tool_use with name in {Bash, Read, Grep, Glob} whose joined
                         string input values match a unit's signature (below)
    orchestratorBytes(unit) := sum of matched-call result bytes, over transcripts with
                                origin == orchestrator
    subagentBytes(unit)     := sum of matched-call result bytes, over transcripts with
                                origin == subagent
    subagentShare(unit)     := subagentBytes / (orchestratorBytes + subagentBytes)
                                null  WHEN the unit never fired (no matched call at all)
                                0.0   WHEN it fired but every matched result was 0 bytes
                                      (never conflated with "never fired")

Unit signatures (echoed verbatim into `units[].signature`):

    G1 qa-gate-run      := Bash matching nx run-many|affected|run … test|lint|typecheck|build,
                            pnpm test|lint, vitest, jest; OR any input naming qa-gate-runner.md
    G2 ac-verification  := input naming docs/superpowers/plans/, a `git log <range> --oneline`,
                            verification-before-completion, or ac-verification.md
    G3 docs-sync-gate   := input naming docs-manifest.md, docs-pipeline, or docs-sync-gate.sh

The return-cap rule (verbatim — the round-trip detector). A unit's "return" is the bytes
its dispatch mechanism contributes back to the ORCHESTRATOR transcript only: for G1/G2, the
tool_result of an `Agent` tool_use whose joined input text names that unit's ref
(`qa-gate-runner.md` / `ac-verification.md`); for G3, the tool_result of a `Bash` tool_use
whose command names `docs-sync-gate.sh` (G3 is a script, not a dispatch — the same call is
both its execution and its return).

    returnBytes(unit)       := sum of the unit's dispatch-return tool_result bytes, orchestrator only
    returnCapBytes          := 2000 (G1) / 4000 (G2) / 200 (G3)  — stated caps, never derived
    returnCapExceeded(unit) := returnBytes(unit) > returnCapBytes(unit)

The residency rule (verbatim — reused unchanged from context-residency.py, but pooled over
the WHOLE resolved corpus — both tiers — because this instrument's population spans both,
unlike context-residency.py's top-level-only scope):

    turn        := a record with type == "assistant"; turns are indexed 1..T in file order,
                   PER TRANSCRIPT
    T           := assistantTurns in that transcript
    result(r)   := an item of record["message"]["content"] with type == "tool_result"
    bytes(r)    := len(result text)
    turn(r)     := the index of the most recent assistant turn at or before r's record
    exposure(r) := bytes(r) * (T - turn(r))
    toolResultBytes     := sum of bytes(r) over every r, over every resolved transcript
    toolResultExposure  := sum of exposure(r) over every r, over every resolved transcript

The cache-read-ratio rule (verbatim — the epic guardrail, AC-2 of NA-91, reused here as a
convenience cross-check; pooled the same way as toolResultBytes/toolResultExposure above):

    cacheReadRatio := cacheRead / (cacheRead + cacheCreation + input)
                       # summed across every assistant-turn usage block in the resolved
                       # corpus; 0.0 when the denominator is 0.

The corpus-completeness rule (verbatim — a partial corpus that reports clean is worse than
one that fails loud; this epic has already under-captured its own corpus three times):

    missing := a raw path/root that could not be resolved to any readable file
    any missing -> print a loud one-line WARNING to stderr naming the count and listing
                   every missing path
    --corpus-list AND missing non-empty -> exit 1  # a pinned corpus list is a deliberate
                   artifact; measuring a silent subset of it is a measurement error
    bare positional paths AND missing non-empty -> WARNING only, exit unaffected

The T3-completeness rule (verbatim — F-14, and the reason this instrument exists):

    ASSERT any resolved subagent path contains "/subagents/workflows/"
    ELSE   print to stderr: "work-placement: WARNING — 0 of N transcripts matched
           */subagents/workflows/wf_*/agent-*.jsonl; a non-recursive glob misses 890 of
           1,447 subagent transcripts (NA-90's shipped bug). Verify the corpus root."

NA-88 D11 — this instrument and its fixtures are authored by the same story that ships the
offload contract it measures. A PASS on `work-placement.test.sh` proves only that the tool
does what its own author designed — it proves NOTHING about whether any real session obeys
the offload contract. This is a smoke test, never a gate on agent behaviour. The pilot (a
story NA-92 does not author) is the only evidence about the contract itself.

Analyser tools are read-only: this script never writes to the repo, to ~/.claude/, or to
any artifact it scans.
"""
import json
import os
import re
import sys
from pathlib import Path

DIRECT_TOOLS = ("Bash", "Read", "Grep", "Glob")

G1_BASH_RE = re.compile(
    r"nx\s+(?:run-many|affected|run)\b[^\n]*\b(?:test|lint|typecheck|build)\b"
    r"|pnpm\s+(?:test|lint)\b"
    r"|\bvitest\b"
    r"|\bjest\b"
)
G2_GIT_LOG_RE = re.compile(r"git log \S+\.\.\S+[^\n]*--oneline")


def match_g1(name, text):
    if name == "Bash" and G1_BASH_RE.search(text):
        return True
    return "qa-gate-runner.md" in text


def match_g2(name, text):
    if "docs/superpowers/plans/" in text:
        return True
    if G2_GIT_LOG_RE.search(text):
        return True
    if "verification-before-completion" in text:
        return True
    if "ac-verification.md" in text:
        return True
    return False


def match_g3(name, text):
    return "docs-manifest.md" in text or "docs-pipeline" in text or "docs-sync-gate.sh" in text


UNITS = [
    {
        "id": "G1",
        "signature": (
            "Bash matching nx run-many|affected|run … test|lint|typecheck|build, "
            "pnpm test|lint, vitest, jest; or any input naming qa-gate-runner.md"
        ),
        "match": match_g1,
        "dispatch_marker": "qa-gate-runner.md",
        "returnCapBytes": 2000,
    },
    {
        "id": "G2",
        "signature": (
            "input naming docs/superpowers/plans/, a git log <range> --oneline, "
            "verification-before-completion, or ac-verification.md"
        ),
        "match": match_g2,
        "dispatch_marker": "ac-verification.md",
        "returnCapBytes": 4000,
    },
    {
        "id": "G3",
        "signature": "input naming docs-manifest.md, docs-pipeline, or docs-sync-gate.sh",
        "match": match_g3,
        "dispatch_marker": "docs-sync-gate.sh",
        "returnCapBytes": 200,
    },
]


def origin_of(transcript_path):
    return "subagent" if "/subagents/" in transcript_path else "orchestrator"


def result_text(item):
    content = item.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for part in content:
            if isinstance(part, dict) and isinstance(part.get("text"), str):
                parts.append(part["text"])
        return "".join(parts)
    return ""


def input_text(item):
    inp = item.get("input") or {}
    parts = [v for v in inp.values() if isinstance(v, str)]
    return "\n".join(parts)


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
            if origin_of(path.replace(os.sep, "/")) == "subagent":
                subagent_files.append(path)
            else:
                t1_files.append(path)
        else:
            missing.append(os.path.abspath(path))
    return t1_files, subagent_files, missing


def new_state(path):
    return {
        "path": path,
        "origin": origin_of(path.replace(os.sep, "/")),
        "turns": 0,
        "results": [],
        "skippedLines": 0,
        "input": 0,
        "cacheRead": 0,
        "cacheCreation": 0,
        "unitBytes": {u["id"]: 0 for u in UNITS},
        "unitFired": {u["id"]: False for u in UNITS},
        "unitReturnBytes": {u["id"]: 0 for u in UNITS},
    }


def is_return_dispatch(unit, name, text):
    marker = unit["dispatch_marker"]
    if marker not in text:
        return False
    if name == "Agent":
        return True
    if unit["id"] == "G3" and name == "Bash":
        return True
    return False


def scan(path):
    state = new_state(path)
    pending_calls = {}
    pending_returns = {}
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                state["skippedLines"] += 1
                continue
            message = record.get("message") or {}
            if record.get("type") == "assistant":
                state["turns"] += 1
                usage = message.get("usage") or record.get("usage")
                if isinstance(usage, dict):
                    state["input"] += usage.get("input_tokens", 0) or 0
                    state["cacheRead"] += usage.get("cache_read_input_tokens", 0) or 0
                    state["cacheCreation"] += usage.get("cache_creation_input_tokens", 0) or 0
            content = message.get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict):
                    continue
                item_type = item.get("type")
                if item_type == "tool_result":
                    tid = item.get("tool_use_id")
                    if not tid:
                        continue
                    text = result_text(item)
                    nbytes = len(text)
                    state["results"].append({"turn": state["turns"], "bytes": nbytes})
                    if tid in pending_calls:
                        uid = pending_calls.pop(tid)
                        state["unitBytes"][uid] += nbytes
                    if tid in pending_returns:
                        uid = pending_returns.pop(tid)
                        state["unitReturnBytes"][uid] += nbytes
                    continue
                if item_type != "tool_use":
                    continue
                name = item.get("name")
                tid = item.get("id")
                text = input_text(item)
                if name in DIRECT_TOOLS:
                    for u in UNITS:
                        if u["match"](name, text):
                            state["unitFired"][u["id"]] = True
                            pending_calls[tid] = u["id"]
                            break
                if state["origin"] == "orchestrator":
                    for u in UNITS:
                        if is_return_dispatch(u, name, text):
                            pending_returns[tid] = u["id"]
                            break
    return state


def build_report(label, corpus, states, missing_count):
    orch = {u["id"]: 0 for u in UNITS}
    sub = {u["id"]: 0 for u in UNITS}
    fired = {u["id"]: False for u in UNITS}
    ret = {u["id"]: 0 for u in UNITS}
    exposure = 0
    total_bytes = 0
    skipped = 0
    inp = 0
    cache_read = 0
    cache_creation = 0
    for state in states:
        total_turns = state["turns"]
        skipped += state["skippedLines"]
        inp += state["input"]
        cache_read += state["cacheRead"]
        cache_creation += state["cacheCreation"]
        for result in state["results"]:
            exposure += result["bytes"] * (total_turns - result["turn"])
            total_bytes += result["bytes"]
        for u in UNITS:
            uid = u["id"]
            fired[uid] = fired[uid] or state["unitFired"][uid]
            ret[uid] += state["unitReturnBytes"][uid]
            if state["origin"] == "orchestrator":
                orch[uid] += state["unitBytes"][uid]
            else:
                sub[uid] += state["unitBytes"][uid]

    units_report = []
    for u in UNITS:
        uid = u["id"]
        total = orch[uid] + sub[uid]
        if not fired[uid]:
            share = None
        elif total == 0:
            share = 0.0
        else:
            share = sub[uid] / total
        units_report.append(
            {
                "id": uid,
                "signature": u["signature"],
                "orchestratorBytes": orch[uid],
                "subagentBytes": sub[uid],
                "subagentShare": share,
                "returnBytes": ret[uid],
                "returnCapBytes": u["returnCapBytes"],
                "returnCapExceeded": ret[uid] > u["returnCapBytes"],
            }
        )

    cache_total = cache_read + cache_creation + inp
    return {
        "label": label,
        "corpus": corpus,
        "units": units_report,
        "toolResultBytes": total_bytes,
        "toolResultExposure": exposure,
        "cacheReadRatio": (cache_read / cache_total) if cache_total else 0.0,
        "skippedLines": skipped,
        "missingCorpusPaths": missing_count,
    }


def print_report(report):
    print("\n### %s" % report["label"])
    print(
        "corpus: %d top-level / %d subagent transcripts"
        % (report["corpus"]["topLevelTranscripts"], report["corpus"]["subagentTranscripts"])
    )
    for u in report["units"]:
        share = "null" if u["subagentShare"] is None else "%.4f" % u["subagentShare"]
        print(
            "%-3s orch %8d  sub %8d  share %-8s return %6d/%-6d cap-exceeded %s"
            % (
                u["id"],
                u["orchestratorBytes"],
                u["subagentBytes"],
                share,
                u["returnBytes"],
                u["returnCapBytes"],
                u["returnCapExceeded"],
            )
        )
    print("toolResultBytes    %d" % report["toolResultBytes"])
    print("toolResultExposure %d byte-turns" % report["toolResultExposure"])
    print("cacheReadRatio     %.4f   (guardrail >= 0.94)" % report["cacheReadRatio"])
    print("skippedLines       %d" % report["skippedLines"])
    print(
        "\nNOTE (NA-88 D11, self-confirming): this instrument and its fixtures were authored by "
        "the same story. A PASS proves only that the tool does what its author designed -- it "
        "proves nothing about whether any session obeys the offload contract."
    )


def parse_argv(argv):
    opts = {"label": None, "raw_paths": [], "corpus_list": None, "json": False}
    positional = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--corpus-list":
            i += 1
            opts["corpus_list"] = argv[i]
        elif arg == "--json":
            opts["json"] = True
        else:
            positional.append(arg)
        i += 1
    if not positional:
        raise ValueError("missing <label>")
    opts["label"] = positional[0]
    opts["raw_paths"] = positional[1:]
    return opts


def usage():
    print(
        "usage: work-placement.py <label> (<transcript.jsonl>... | --corpus-list <file>) [--json]",
        file=sys.stderr,
    )


def main(argv):
    try:
        opts = parse_argv(argv)
    except (ValueError, IndexError) as exc:
        print("work-placement: %s" % exc, file=sys.stderr)
        usage()
        return 2

    raw_entries = read_corpus_list(opts["corpus_list"]) if opts["corpus_list"] else opts["raw_paths"]
    if not raw_entries:
        usage()
        return 2

    t1_files, subagent_files, missing = resolve_corpus(raw_entries)
    if not t1_files and not subagent_files:
        attempted = missing or raw_entries
        print(
            "work-placement: no transcript files found; resolved path(s) tried:\n  "
            + "\n  ".join(attempted),
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    if missing:
        print(
            "work-placement: WARNING — %d of %d corpus roots did not resolve to a readable "
            "file or directory and were dropped:\n  " % (len(missing), len(raw_entries))
            + "\n  ".join(missing),
            file=sys.stderr,
        )
        if opts["corpus_list"]:
            exit_code = 1

    resolved_paths = t1_files + subagent_files
    has_t3 = any("/subagents/workflows/" in p.replace(os.sep, "/") for p in subagent_files)
    if not has_t3:
        print(
            "work-placement: WARNING — 0 of %d transcripts matched "
            "*/subagents/workflows/wf_*/agent-*.jsonl; a non-recursive glob misses 890 of "
            "1,447 subagent transcripts (NA-90's shipped bug). Verify the corpus root."
            % len(resolved_paths),
            file=sys.stderr,
        )

    states = [scan(p) for p in resolved_paths]
    corpus = {
        "topLevelTranscripts": sum(1 for s in states if s["origin"] == "orchestrator"),
        "subagentTranscripts": sum(1 for s in states if s["origin"] == "subagent"),
    }
    report = build_report(opts["label"], corpus, states, len(missing))

    if opts["json"]:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)

    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
