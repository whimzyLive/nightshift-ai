#!/usr/bin/env python3
"""
read-bounding.py — NA-90 read-volume analyser (workstream E, Epic NA-76).

The read-sizing rule (verbatim — an unstated rule makes before/after non-reproducible):

    a Read call := an item of record["message"]["content"] with type == "tool_use" and name == "Read"
    its result  := the item with type == "tool_result" and tool_use_id == that call's id
    estTokens   := floor(len(result text) / 3.7)          # the bytes actually billed, not a file-size estimate
    lines       := result text newline count + 1          # drives the windowed-cost model in Decision 2
    windowed    := input.offset is not None OR input.limit is not None
    whole       := NOT windowed
    a call with no matched result -> excluded from every volume figure, counted in unmatchedCalls

The corpus rule (verbatim):

    origin := subagent   IF the transcript path contains "/subagents/"
    origin := orchestrator OTHERWISE
    # isSidechain is NOT usable on this harness: 0 of 69,092 records carry it. Do not partition on it.
    ASSERT corpus.subagentTranscripts > 0 ELSE print a loud one-line WARNING naming the
           */subagents/*.jsonl glob and that ~88% of read volume is likely missing
           # a warning, never exit 1 — a deliberately orchestrator-only run is legitimate

The carve-out rule (verbatim):

    carveOutEligible := a read whose result is <= windowLines lines   # a windowed read here returns the whole file anyway
    carveOutHits     := eligible reads taken WHOLE      # the carve-out was honoured
    carveOutMisses   := eligible reads taken WINDOWED   # net LOSS: the Grep bought nothing
    carveOutHitRate  := carveOutHits / carveOutEligible
    # 468 of 681 addressable reads (68.7%) are eligible. An aggregate win with a low hit rate is
    # a systematic loss on the majority, hidden by the mean — report both, always.

NA-88 D11 — this instrument is self-confirming, not independent evidence. Its fixtures and its
code are authored by the same story; a PASS proves only that the tool does what its author
intended. It proves nothing about whether any agent obeys the `## Bounded reads` clause. Gate 3
(a pilot on an independent story) is the only evidence about the contract itself. Falsifiability:
this tool must return three different answers over the fixed all-windowed / all-whole / real-corpus
fixtures (1.0 / 0.0 / ~0.26) — a tool returning the same number against all three would be
incapable of measuring anything.

Analyser tools are read-only: this script never writes to the repo, to ~/.claude/, or to any
artifact it scans.
"""
import json
import math
import os
import re
import sys
from collections import defaultdict

STORY_KEY_RE = re.compile(r"([A-Za-z]{2,10}-\d+)")

CATEGORY_ORDER = [
    "plugin-instruction",
    "self-generated-artifact",
    "project-config",
    "source-other",
]

ORIGIN_ORDER = ["orchestrator", "subagent"]

DEFAULT_THRESHOLD = 2000
DEFAULT_WINDOW_LINES = 400


def story_key(git_branch):
    if not git_branch:
        return None
    match = STORY_KEY_RE.search(git_branch)
    return match.group(1).upper() if match else None


def classify_category(path):
    if "plugins/sdlc/" in path or ("/plugins/" in path and "/sdlc/" in path):
        return "plugin-instruction"
    if "docs/superpowers/" in path or ".claude/memories" in path:
        return "self-generated-artifact"
    if ".claude/" in path or os.path.basename(path) in ("CLAUDE.md", "AGENTS.md"):
        return "project-config"
    return "source-other"


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


def scan(path, reads, results, skipped_counter):
    origin = origin_of(path)
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                skipped_counter[0] += 1
                continue
            content = (record.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            story = story_key(record.get("gitBranch")) or "unlabeled"
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "tool_result" and item.get("tool_use_id"):
                    results[item["tool_use_id"]] = result_text(item)
                    continue
                if item.get("type") != "tool_use" or item.get("name") != "Read":
                    continue
                inp = item.get("input") or {}
                file_path = inp.get("file_path")
                if not file_path:
                    continue
                reads.append(
                    {
                        "id": item.get("id"),
                        "path": os.path.expanduser(file_path),
                        "origin": origin,
                        "story": story,
                        "windowed": inp.get("offset") is not None or inp.get("limit") is not None,
                    }
                )


def size_reads(reads, results):
    sized, unmatched = [], 0
    for r in reads:
        text = results.get(r["id"])
        if text is None:
            unmatched += 1
            continue
        entry = dict(r)
        entry["estTokens"] = int(math.floor(len(text) / 3.7))
        entry["lines"] = text.count("\n") + 1
        entry["category"] = classify_category(r["path"])
        sized.append(entry)
    return sized, unmatched


def percentile(values, pct):
    if not values:
        return 0
    ordered = sorted(values)
    idx = int(math.ceil(pct / 100.0 * len(ordered))) - 1
    return ordered[max(0, min(idx, len(ordered) - 1))]


def carve_out_stats(sized, window_lines):
    eligible = [r for r in sized if r["lines"] <= window_lines]
    hits = sum(1 for r in eligible if not r["windowed"])
    misses = len(eligible) - hits
    rate = (hits / len(eligible)) if eligible else 0
    return {
        "windowLines": window_lines,
        "carveOutEligibleReads": len(eligible),
        "carveOutHits": hits,
        "carveOutMisses": misses,
        "carveOutHitRate": rate,
    }


def build_report(label, sized, corpus, threshold, window_lines, unmatched, skipped_lines):
    total = len(sized)
    windowed = [r for r in sized if r["windowed"]]
    whole = [r for r in sized if not r["windowed"]]
    windowed_reads = len(windowed)
    windowed_share = (windowed_reads / total) if total else 0

    est_tokens = [r["estTokens"] for r in sized]
    total_est_tokens = sum(est_tokens)
    windowed_est_tokens = sum(r["estTokens"] for r in windowed)

    top_decile_n = int(math.ceil(total / 10.0)) if total else 0
    top_decile_volume = sum(sorted(est_tokens, reverse=True)[:top_decile_n]) if top_decile_n else 0
    top_decile_share = (top_decile_volume / total_est_tokens) if total_est_tokens else 0

    whole_reads_over_threshold = sum(1 for r in whole if r["estTokens"] >= threshold)

    by_origin = {o: 0 for o in ORIGIN_ORDER}
    for r in sized:
        by_origin[r["origin"]] += 1

    by_category = {c: 0 for c in CATEGORY_ORDER}
    for r in sized:
        by_category[r["category"]] += 1

    by_path = defaultdict(lambda: {"reads": 0, "estTokens": 0})
    for r in whole:
        by_path[r["path"]]["reads"] += 1
        by_path[r["path"]]["estTokens"] += r["estTokens"]
    top_paths = sorted(
        (
            {"path": p, "reads": v["reads"], "estTokens": v["estTokens"]}
            for p, v in by_path.items()
        ),
        key=lambda r: (-r["estTokens"], -r["reads"], r["path"]),
    )[:10]

    stories_observed = len({r["story"] for r in sized})
    est_tokens_per_story = (total_est_tokens / stories_observed) if stories_observed else 0

    report = {
        "label": label,
        "corpus": corpus,
        "totalReads": total,
        "windowedReads": windowed_reads,
        "windowedShare": windowed_share,
        "totalEstTokens": total_est_tokens,
        "windowedEstTokens": windowed_est_tokens,
        "p50EstTokens": percentile(est_tokens, 50),
        "p95EstTokens": percentile(est_tokens, 95),
        "maxEstTokens": max(est_tokens) if est_tokens else 0,
        "topDecileShare": top_decile_share,
        "wholeReadsOverThreshold": whole_reads_over_threshold,
        "thresholdEstTokens": threshold,
        "byOrigin": [{"origin": o, "reads": by_origin[o]} for o in ORIGIN_ORDER],
        "byCategory": [{"category": c, "reads": by_category[c]} for c in CATEGORY_ORDER],
        "topPaths": top_paths,
        "skippedLines": skipped_lines,
        "unmatchedCalls": unmatched,
    }
    report.update(carve_out_stats(sized, window_lines))
    report["storiesObserved"] = stories_observed
    report["estTokensPerStory"] = est_tokens_per_story
    return report


def print_report(report):
    print(f"\n### {report['label']}")
    print(
        "corpus: %d top-level / %d subagent transcripts"
        % (report["corpus"]["topLevelTranscripts"], report["corpus"]["subagentTranscripts"])
    )
    pct = report["windowedShare"] * 100
    print(
        "totalReads %d  windowedReads %d (%.1f%%)  unmatchedCalls %d  skippedLines %d"
        % (report["totalReads"], report["windowedReads"], pct, report["unmatchedCalls"], report["skippedLines"])
    )
    print(
        "totalEstTokens %d  windowedEstTokens %d  p50 %d  p95 %d  max %d  topDecileShare %.1f%%"
        % (
            report["totalEstTokens"],
            report["windowedEstTokens"],
            report["p50EstTokens"],
            report["p95EstTokens"],
            report["maxEstTokens"],
            report["topDecileShare"] * 100,
        )
    )
    print(
        "wholeReadsOverThreshold %d (>= %d est tok)"
        % (report["wholeReadsOverThreshold"], report["thresholdEstTokens"])
    )
    print(
        "windowLines %d  carveOutEligibleReads %d  carveOutHits %d  carveOutMisses %d  carveOutHitRate %.2f"
        % (
            report["windowLines"],
            report["carveOutEligibleReads"],
            report["carveOutHits"],
            report["carveOutMisses"],
            report["carveOutHitRate"],
        )
    )
    print(
        "storiesObserved %d  estTokensPerStory %.1f"
        % (report["storiesObserved"], report["estTokensPerStory"])
    )
    print("by origin:")
    for row in report["byOrigin"]:
        print(f"  {row['origin']:14}reads {row['reads']:>6}")
    print("by category:")
    for row in report["byCategory"]:
        print(f"  {row['category']:24}reads {row['reads']:>6}")
    if report["topPaths"]:
        print("top paths (by whole-read volume):")
        for p in report["topPaths"]:
            print(f"  estTokens {p['estTokens']:>8}  reads {p['reads']:>4}  {p['path']}")
    print(
        "\nNOTE (NA-88 D11, self-confirming): this instrument and its fixtures were authored by "
        "the same story. A PASS proves only that the tool does what its author designed -- it "
        "proves nothing about whether any agent obeys the '## Bounded reads' clause or that any "
        "token was saved."
    )


def parse_argv(argv):
    opts = {
        "label": None,
        "raw_paths": [],
        "corpus_list": None,
        "threshold": DEFAULT_THRESHOLD,
        "window_lines": DEFAULT_WINDOW_LINES,
        "per_story": False,
        "json": False,
    }
    positional = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--corpus-list":
            i += 1
            opts["corpus_list"] = argv[i]
        elif arg == "--threshold":
            i += 1
            raw = argv[i]
            try:
                opts["threshold"] = int(raw)
            except ValueError:
                raise ValueError("--threshold requires a numeric value, got: %s" % raw)
        elif arg == "--window-lines":
            i += 1
            raw = argv[i]
            try:
                opts["window_lines"] = int(raw)
            except ValueError:
                raise ValueError("--window-lines requires a numeric value, got: %s" % raw)
        elif arg == "--per-story":
            opts["per_story"] = True
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
        "usage: read-bounding.py <label> (<transcript.jsonl>... | --corpus-list <file>) "
        "[--threshold N] [--window-lines N] [--per-story] [--json]",
        file=sys.stderr,
    )


def main(argv):
    try:
        opts = parse_argv(argv)
    except (ValueError, IndexError) as exc:
        print("read-bounding: %s" % exc, file=sys.stderr)
        usage()
        return 2

    if opts["corpus_list"]:
        raw_paths = read_corpus_list(opts["corpus_list"])
    else:
        raw_paths = opts["raw_paths"]

    if not raw_paths:
        usage()
        return 2

    resolved_paths, missing_paths = resolve_paths(raw_paths)
    if not resolved_paths:
        attempted = missing_paths or raw_paths
        print(
            "read-bounding: no transcript files found; resolved path(s) tried:\n  "
            + "\n  ".join(attempted),
            file=sys.stderr,
        )
        return 1

    exit_code = 0
    if missing_paths:
        print(
            "read-bounding: WARNING — %d of %d corpus paths did not resolve to a readable "
            "file and were dropped:\n  " % (len(missing_paths), len(raw_paths))
            + "\n  ".join(missing_paths),
            file=sys.stderr,
        )
        if opts["corpus_list"]:
            exit_code = 1

    top_level = sum(1 for p in resolved_paths if origin_of(p) == "orchestrator")
    subagent = sum(1 for p in resolved_paths if origin_of(p) == "subagent")
    if subagent == 0:
        print(
            "read-bounding: WARNING — 0 of %d transcripts matched */subagents/*.jsonl; "
            "a non-recursive glob drops ~88%% of read volume (see NA-88's corrected baseline)"
            % len(resolved_paths),
            file=sys.stderr,
        )

    reads = []
    results = {}
    skipped_counter = [0]
    for path in resolved_paths:
        scan(path, reads, results, skipped_counter)
    sized, unmatched = size_reads(reads, results)

    corpus = {"topLevelTranscripts": top_level, "subagentTranscripts": subagent}

    if opts["per_story"]:
        stories = sorted({r["story"] for r in sized})
        for story in stories:
            story_sized = [r for r in sized if r["story"] == story]
            report = build_report(
                f"{opts['label']}: {story}",
                story_sized,
                corpus,
                opts["threshold"],
                opts["window_lines"],
                sum(1 for r in reads if r["story"] == story and results.get(r["id"]) is None),
                skipped_counter[0],
            )
            if opts["json"]:
                print(json.dumps(report, indent=2))
            else:
                print_report(report)
    else:
        report = build_report(
            opts["label"], sized, corpus, opts["threshold"], opts["window_lines"], unmatched, skipped_counter[0]
        )
        if opts["json"]:
            print(json.dumps(report, indent=2))
        else:
            print_report(report)

    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
