#!/usr/bin/env python3
import json
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


def window_of(offset, limit):
    start = offset if offset is not None else 1
    length = limit if limit is not None else 2000
    return (start, start + length - 1)


def intersects(w1, w2):
    return not (w1[1] < w2[0] or w2[1] < w1[0])


def classify_read(state, is_whole, win):
    if not state["windows"]:
        return "first"
    if state["hadWhole"]:
        return "redundant"
    if is_whole:
        return "redundant"
    for w in state["windows"]:
        if intersects(w, win):
            return "overlapping"
    return "disjoint"


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


def scan(path, partitions, events, story_of_path):
    skipped = 0
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
            content = (record.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            is_sidechain = bool(record.get("isSidechain"))
            story = story_key(record.get("gitBranch")) or "unlabeled"
            partition_key = (path, is_sidechain)
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") != "tool_use" or item.get("name") != "Read":
                    continue
                inp = item.get("input") or {}
                file_path = inp.get("file_path")
                if not file_path:
                    continue
                file_path = os.path.expanduser(file_path)
                offset = inp.get("offset")
                limit = inp.get("limit")
                is_whole = offset is None and limit is None
                win = window_of(offset, limit)

                state = partitions[partition_key][file_path]
                klass = classify_read(state, is_whole, win)
                state["windows"].append(win)
                if is_whole:
                    state["hadWhole"] = True

                category = classify_category(file_path)
                events.append(
                    {
                        "story": story,
                        "category": category,
                        "klass": klass,
                        "path": file_path,
                    }
                )
                story_of_path[path].add(story)
    return skipped


def new_partition_state():
    return {"hadWhole": False, "windows": []}


def build_report(label, events, sessions):
    total = len(events)
    first_read = sum(1 for e in events if e["klass"] == "first")
    redundant = sum(1 for e in events if e["klass"] == "redundant")
    overlapping = sum(1 for e in events if e["klass"] == "overlapping")
    disjoint = sum(1 for e in events if e["klass"] == "disjoint")
    redundant_share = (redundant / total) if total else 0

    by_category = {c: {"reads": 0, "redundant": 0} for c in CATEGORY_ORDER}
    by_path = defaultdict(lambda: {"reads": 0, "redundant": 0})
    for e in events:
        by_category[e["category"]]["reads"] += 1
        if e["klass"] == "redundant":
            by_category[e["category"]]["redundant"] += 1
        by_path[e["path"]]["reads"] += 1
        if e["klass"] == "redundant":
            by_path[e["path"]]["redundant"] += 1

    top_paths = sorted(
        (
            {"path": p, "reads": v["reads"], "redundant": v["redundant"]}
            for p, v in by_path.items()
        ),
        key=lambda r: (-r["redundant"], -r["reads"], r["path"]),
    )[:10]

    return {
        "label": label,
        "sessions": sessions,
        "totalReads": total,
        "firstRead": first_read,
        "redundantAfterWhole": redundant,
        "overlappingWindow": overlapping,
        "disjointWindow": disjoint,
        "redundantShare": redundant_share,
        "byCategory": [
            {"category": c, "reads": by_category[c]["reads"], "redundant": by_category[c]["redundant"]}
            for c in CATEGORY_ORDER
        ],
        "topPaths": top_paths,
    }


def print_report(report, skipped_lines):
    print(f"\n### {report['label']}")
    print(f"sessions: {report['sessions']}  totalReads: {report['totalReads']}  skippedLines: {skipped_lines}")
    pct = report["redundantShare"] * 100
    print(
        f"first {report['firstRead']} / redundant {report['redundantAfterWhole']} "
        f"({pct:.1f}%) / overlapping {report['overlappingWindow']} / disjoint {report['disjointWindow']}"
    )
    print("by category:")
    for c in report["byCategory"]:
        print(f"  {c['category']:24}reads {c['reads']:>5}  redundant {c['redundant']:>5}")
    if report["topPaths"]:
        print("top paths (by redundant reads):")
        for p in report["topPaths"]:
            print(f"  redundant {p['redundant']:>4}  reads {p['reads']:>4}  {p['path']}")


def main(argv):
    json_out = "--json" in argv
    per_story = "--per-story" in argv
    positional = [a for a in argv if a not in ("--json", "--per-story")]
    if len(positional) < 2:
        print(
            "usage: duplicate-reads.py <label> <transcript.jsonl>... [--per-story] [--json]",
            file=sys.stderr,
        )
        return 1
    label, raw_paths = positional[0], positional[1:]

    resolved_paths, missing_paths = resolve_paths(raw_paths)
    if not resolved_paths:
        attempted = missing_paths or [os.path.expanduser("~/.claude/projects")]
        print(
            "duplicate-reads: no transcript files found; resolved path(s): " + ", ".join(attempted),
            file=sys.stderr,
        )
        return 1

    # This tool has no --corpus-list flag (bare positional paths only), so there is no "pinned
    # list" distinction to key a fatal exit on — sibling tools (context-residency.py,
    # work-placement.py, read-bounding.py) only exit non-zero here when the miss came from a
    # pinned --corpus-list; a bare positional miss is loud but non-fatal in all of them too.
    if missing_paths:
        print(
            "duplicate-reads: WARNING — %d of %d corpus paths did not resolve to a readable "
            "file and were dropped:\n  " % (len(missing_paths), len(raw_paths))
            + "\n  ".join(missing_paths),
            file=sys.stderr,
        )

    partitions = defaultdict(lambda: defaultdict(new_partition_state))
    events = []
    story_of_path = defaultdict(set)
    skipped_lines = 0
    for path in resolved_paths:
        skipped_lines += scan(path, partitions, events, story_of_path)

    if per_story:
        stories = sorted({e["story"] for e in events})
        for story in stories:
            story_events = [e for e in events if e["story"] == story]
            sessions = sum(1 for p in resolved_paths if story in story_of_path[p])
            report = build_report(f"{label}: {story}", story_events, sessions)
            if json_out:
                out = dict(report)
                out["skippedLines"] = skipped_lines
                print(json.dumps(out, indent=2))
            else:
                print_report(report, skipped_lines)
    else:
        report = build_report(label, events, len(resolved_paths))
        if json_out:
            out = dict(report)
            out["skippedLines"] = skipped_lines
            print(json.dumps(out, indent=2))
        else:
            print_report(report, skipped_lines)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
