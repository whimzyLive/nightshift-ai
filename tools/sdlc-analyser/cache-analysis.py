#!/usr/bin/env python3
import json
import os
import re
import sys
from collections import defaultdict

PRICE = {"opus": (5, 25), "sonnet": (3, 15), "haiku": (1, 5), "?": (5, 25)}
STORY_KEY_RE = re.compile(r"([A-Za-z]{2,10}-\d+)")


def tier(model):
    model = (model or "").lower()
    if "opus" in model:
        return "opus"
    if "sonnet" in model:
        return "sonnet"
    if "haiku" in model:
        return "haiku"
    return "?"


def story_key(git_branch):
    if not git_branch:
        return None
    match = STORY_KEY_RE.search(git_branch)
    return match.group(1).upper() if match else None


def new_bucket():
    return dict(inp=0, cr=0, cw=0, out=0, n=0)


def scan(path, groups):
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            try:
                record = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            message = record.get("message") or {}
            usage = message.get("usage") or record.get("usage")
            if not isinstance(usage, dict):
                continue
            group_key = story_key(record.get("gitBranch")) or "unlabeled"
            model_tier = tier(message.get("model") or record.get("model"))
            bucket = groups[group_key][model_tier]
            bucket["inp"] += usage.get("input_tokens", 0) or 0
            bucket["cr"] += usage.get("cache_read_input_tokens", 0) or 0
            bucket["cw"] += usage.get("cache_creation_input_tokens", 0) or 0
            bucket["out"] += usage.get("output_tokens", 0) or 0
            bucket["n"] += 1


def report(tiers_by_model, label):
    print(f"\n### {label}")
    header = f"{'model':8}{'reqs':>6}{'fresh in':>12}{'cache rd':>12}{'cache wr':>12}{'output':>11}{'hit%':>7}{'$ actual':>10}{'$ nocache':>11}"
    print(header)
    grand_total = new_bucket()
    cost_actual = 0.0
    cost_no_cache = 0.0
    for model_tier, bucket in sorted(tiers_by_model.items()):
        total_in = bucket["inp"] + bucket["cr"] + bucket["cw"]
        hit_rate = 100 * bucket["cr"] / total_in if total_in else 0
        price_in, price_out = PRICE[model_tier]
        actual = (
            bucket["inp"] * price_in
            + bucket["cr"] * price_in * 0.1
            + bucket["cw"] * price_in * 1.25
            + bucket["out"] * price_out
        ) / 1e6
        no_cache = (total_in * price_in + bucket["out"] * price_out) / 1e6
        cost_actual += actual
        cost_no_cache += no_cache
        for key in grand_total:
            grand_total[key] += bucket[key]
        print(
            f"{model_tier:8}{bucket['n']:>6}{bucket['inp']:>12,}{bucket['cr']:>12,}"
            f"{bucket['cw']:>12,}{bucket['out']:>11,}{hit_rate:>6.1f}%{actual:>10.2f}{no_cache:>11.2f}"
        )
    total_in = grand_total["inp"] + grand_total["cr"] + grand_total["cw"]
    hit_rate = 100 * grand_total["cr"] / total_in if total_in else 0
    print(
        f"{'TOTAL':8}{grand_total['n']:>6}{grand_total['inp']:>12,}{grand_total['cr']:>12,}"
        f"{grand_total['cw']:>12,}{grand_total['out']:>11,}{hit_rate:>6.1f}%{cost_actual:>10.2f}{cost_no_cache:>11.2f}"
    )
    saved_pct = 100 * (1 - cost_actual / cost_no_cache) if cost_no_cache else 0
    print(f"  cache saved ${cost_no_cache - cost_actual:.2f} ({saved_pct:.0f}% off no-cache)")
    return grand_total, cost_actual, cost_no_cache


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


def main(argv):
    per_story = "--per-story" in argv
    positional = [a for a in argv if a != "--per-story"]
    if len(positional) < 1:
        print("usage: cache-analysis.py <label> <transcript.jsonl>... [--per-story]", file=sys.stderr)
        return 1
    label, raw_paths = positional[0], positional[1:]

    resolved_paths, missing_paths = resolve_paths(raw_paths)
    if not resolved_paths:
        attempted = missing_paths or [os.path.expanduser("~/.claude/projects")]
        print(
            "cache-analysis: no transcript files found; resolved path(s): " + ", ".join(attempted),
            file=sys.stderr,
        )
        return 1

    groups = defaultdict(lambda: defaultdict(new_bucket))
    for path in resolved_paths:
        scan(path, groups)

    if per_story:
        for story in sorted(groups):
            report(groups[story], f"{label}: {story}")
    else:
        merged = defaultdict(new_bucket)
        for story_groups in groups.values():
            for model_tier, bucket in story_groups.items():
                for key in merged[model_tier]:
                    merged[model_tier][key] += bucket[key]
        report(merged, label)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
