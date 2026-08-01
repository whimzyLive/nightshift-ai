#!/usr/bin/env python3
"""
context-residency.py — NA-91 top-level context-residency analyser (workstream F, Epic NA-76).

The residency rule (verbatim — an unstated rule makes before/after non-reproducible):

    turn        := a record with type == "assistant"; turns are indexed 1..T in file order
    T           := assistantTurns, the count of such records in the transcript
    result(r)   := an item of record["message"]["content"] with type == "tool_result"
    bytes(r)    := len(result text)                     # the bytes actually resident
    turn(r)     := the index of the most recent assistant turn at or before r's record
    exposure(r) := bytes(r) * (T - turn(r))             # re-billed on every turn after it entered
    toolResultExposure := sum of exposure(r) over all r

The boundary rule (verbatim):

    boundaryTurn := index of the FIRST assistant turn carrying a tool_use with name == "Bash" whose
                    input.command contains "raise-pr.sh" or "gh pr create"; null when absent
    inheritedExposure := sum over r with turn(r) <= boundaryTurn of bytes(r) * (T - boundaryTurn)
    inheritedShare    := inheritedExposure / toolResultExposure ; 0.0 when boundaryTurn is null
    --boundary none -> boundaryTurn forced to null      # the control arm
    boundaryTurn is reported only for a SINGLE-transcript run; a pooled corpus reports null and
      transcriptsWithBoundary instead

The corpus rule (verbatim):

    origin := subagent   IF the transcript path contains "/subagents/"
    origin := orchestrator OTHERWISE
    ASSERT corpus.subagentTranscripts == 0 ELSE print a loud one-line WARNING naming the count
           # F's population is the TOP-LEVEL session ONLY; never silently pool the two populations
           # a warning, never exit 1 — a deliberately mixed run is the caller's business to explain

The corpus-completeness rule (verbatim — a partial corpus that reports clean is worse than one
that fails loud; this epic has already under-captured its own corpus three times):

    missing := a raw path that resolve_paths() could not resolve to a readable file
    any missing path -> print a loud one-line WARNING to stderr naming the count and listing
                         every missing path, same register as the subagentTranscripts WARNING
    --corpus-list AND missing non-empty -> exit 1  # a pinned corpus list is a deliberate
                         artifact; measuring a silent subset of it is a measurement error, not
                         a convenience
    bare positional paths AND missing non-empty -> WARNING only, exit unaffected  # an ad-hoc
                         path list on the command line is already the caller's own choice of
                         what to include; there is no pinned artifact to fall short of

The cache-read-ratio rule (verbatim — this is the one metric AC-2's >= 94% guardrail is scored
against, so its formula is stated with the same discipline as the three rules above):

    cacheReadRatio := cacheRead / (cacheRead + cacheCreation + input)
                       # summed across every assistant-turn usage block in the corpus;
                       # 0.0 when the denominator is 0. input_tokens IS included in the
                       # denominator — a real choice that moves the number away from a
                       # cache-read-only ratio; stated here so a before/after comparison
                       # never has to re-derive it from source.

NA-88 D11 — this instrument is self-confirming, not independent evidence. Its fixtures and its
code are authored by the same story; a PASS proves only that the tool does what its author
intended. It proves nothing about whether any session obeys the boundary. Gate 3 (a pilot on an
independent story) is the only evidence about the boundary itself.

Analyser tools are read-only: this script never writes to the repo, to ~/.claude/, or to any
artifact it scans.
"""
import json
import os
import sys

BOUNDARY_MARKERS = ("raise-pr.sh", "gh pr create")
BOUNDARY_MODES = ("pr-raise", "none")


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


def resolve_paths(raw_paths):
    resolved = []
    missing = []
    for raw in raw_paths:
        path = os.path.expanduser(raw)
        if os.path.isfile(path):
            resolved.append(path)
        else:
            missing.append(os.path.abspath(path))
    return resolved, missing


def read_corpus_list(list_path):
    base = os.path.dirname(os.path.abspath(list_path))
    paths = []
    with open(list_path, encoding="utf-8") as f:
        for raw in f:
            entry = raw.strip()
            if not entry or entry.startswith("#"):
                continue
            entry = os.path.expanduser(entry)
            if not os.path.isabs(entry):
                entry = os.path.join(base, entry)
            paths.append(entry)
    return paths


def new_state(path):
    return {
        "path": path,
        "turns": 0,
        "results": [],
        "boundaryTurn": None,
        "boundaryCommand": None,
        "skippedLines": 0,
        "input": 0,
        "cacheRead": 0,
        "cacheCreation": 0,
    }


def scan(path):
    state = new_state(path)
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
                if item.get("type") == "tool_result":
                    state["results"].append(
                        {"turn": state["turns"], "bytes": len(result_text(item))}
                    )
                    continue
                if item.get("type") != "tool_use":
                    continue
                if state["boundaryTurn"] is not None or item.get("name") != "Bash":
                    continue
                command = (item.get("input") or {}).get("command") or ""
                for marker in BOUNDARY_MARKERS:
                    if marker in command:
                        state["boundaryTurn"] = state["turns"]
                        state["boundaryCommand"] = command
                        break
    return state


def build_report(label, corpus, states, boundary_mode):
    exposure = 0
    inherited = 0
    turns = 0
    skipped = 0
    inp = 0
    cache_read = 0
    cache_creation = 0
    with_boundary = 0
    for state in states:
        total_turns = state["turns"]
        boundary = None if boundary_mode == "none" else state["boundaryTurn"]
        turns += total_turns
        skipped += state["skippedLines"]
        inp += state["input"]
        cache_read += state["cacheRead"]
        cache_creation += state["cacheCreation"]
        if boundary is not None:
            with_boundary += 1
        for result in state["results"]:
            exposure += result["bytes"] * (total_turns - result["turn"])
            if boundary is not None and result["turn"] <= boundary:
                inherited += result["bytes"] * (total_turns - boundary)
    single = states[0] if len(states) == 1 and boundary_mode != "none" else None
    cache_total = cache_read + cache_creation + inp
    return {
        "label": label,
        "topLevelTranscripts": corpus["topLevelTranscripts"],
        "subagentTranscripts": corpus["subagentTranscripts"],
        "assistantTurns": turns,
        "toolResultExposure": exposure,
        "boundaryTurn": single["boundaryTurn"] if single else None,
        "boundaryCommand": single["boundaryCommand"] if single else None,
        "transcriptsWithBoundary": with_boundary,
        "inheritedExposure": inherited,
        "inheritedShare": (inherited / exposure) if exposure else 0.0,
        "cacheReadRatio": (cache_read / cache_total) if cache_total else 0.0,
        "skippedLines": skipped,
    }


def print_report(report):
    print("\n### %s" % report["label"])
    print(
        "corpus: %d top-level / %d subagent transcripts, %d assistant turns"
        % (
            report["topLevelTranscripts"],
            report["subagentTranscripts"],
            report["assistantTurns"],
        )
    )
    print("tool-result exposure:    %d byte-turns" % report["toolResultExposure"])
    print("boundary turn:           %s" % report["boundaryTurn"])
    print("transcripts w/ boundary: %d" % report["transcriptsWithBoundary"])
    print("inherited exposure:      %d byte-turns" % report["inheritedExposure"])
    print("inherited share:         %.4f" % report["inheritedShare"])
    print("cache-read ratio:        %.4f   (guardrail >= 0.94)" % report["cacheReadRatio"])
    print("skipped lines:           %d" % report["skippedLines"])


def parse_argv(argv):
    opts = {
        "label": None,
        "raw_paths": [],
        "corpus_list": None,
        "boundary": "pr-raise",
        "per_transcript": False,
        "json": False,
    }
    positional = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--corpus-list":
            i += 1
            opts["corpus_list"] = argv[i]
        elif arg == "--boundary":
            i += 1
            raw = argv[i]
            if raw not in BOUNDARY_MODES:
                raise ValueError(
                    "--boundary must be one of %s, got: %s" % ("|".join(BOUNDARY_MODES), raw)
                )
            opts["boundary"] = raw
        elif arg == "--per-transcript":
            opts["per_transcript"] = True
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
        "usage: context-residency.py <label> (<transcript.jsonl>... | --corpus-list <file>) "
        "[--boundary pr-raise|none] [--per-transcript] [--json]",
        file=sys.stderr,
    )


def main(argv):
    try:
        opts = parse_argv(argv)
    except (ValueError, IndexError) as exc:
        print("context-residency: %s" % exc, file=sys.stderr)
        usage()
        return 2

    raw_paths = read_corpus_list(opts["corpus_list"]) if opts["corpus_list"] else opts["raw_paths"]
    if not raw_paths:
        usage()
        return 2

    resolved_paths, missing_paths = resolve_paths(raw_paths)
    if not resolved_paths:
        attempted = missing_paths or raw_paths
        print(
            "context-residency: no transcript files found; resolved path(s) tried:\n  "
            + "\n  ".join(attempted),
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    if missing_paths:
        print(
            "context-residency: WARNING — %d of %d corpus paths did not resolve to a readable "
            "file and were dropped:\n  " % (len(missing_paths), len(raw_paths))
            + "\n  ".join(missing_paths),
            file=sys.stderr,
        )
        if opts["corpus_list"]:
            exit_code = 1

    top_level = sum(1 for p in resolved_paths if origin_of(p) == "orchestrator")
    subagent = sum(1 for p in resolved_paths if origin_of(p) == "subagent")
    if subagent:
        print(
            "context-residency: WARNING — %d of %d transcripts are subagent transcripts; F's "
            "population is the TOP-LEVEL session only, and the two are never pooled silently"
            % (subagent, len(resolved_paths)),
            file=sys.stderr,
        )

    corpus = {"topLevelTranscripts": top_level, "subagentTranscripts": subagent}
    states = [scan(path) for path in resolved_paths]

    if opts["per_transcript"]:
        for state in states:
            one = {
                "topLevelTranscripts": 1 if origin_of(state["path"]) == "orchestrator" else 0,
                "subagentTranscripts": 1 if origin_of(state["path"]) == "subagent" else 0,
            }
            report = build_report(
                "%s: %s" % (opts["label"], os.path.basename(state["path"])),
                one,
                [state],
                opts["boundary"],
            )
            if opts["json"]:
                print(json.dumps(report, indent=2))
                print()
            else:
                print_report(report)
    else:
        report = build_report(opts["label"], corpus, states, opts["boundary"])
        if opts["json"]:
            print(json.dumps(report, indent=2))
        else:
            print_report(report)

    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
