#!/usr/bin/env python3
"""Resolve a ticket into a normalised story document.

Usage:
  python3 resolve.py --key NA-80 --repo /path/to/repo --out story.json
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import acli, config  # noqa: E402

_AC_HEADING = re.compile(r"^\s*acceptance criteria\s*:?\s*$", re.IGNORECASE)
_NEXT_HEADING = re.compile(
    r"^\s*(non-?goals?|notes?|prerequisites?|out of scope|objective)\s*:?\s*$", re.IGNORECASE
)


def extract_acs(description: str) -> str:
    lines = description.splitlines()
    collecting = False
    out = []
    for line in lines:
        if _AC_HEADING.match(line):
            collecting = True
            continue
        if collecting and _NEXT_HEADING.match(line):
            break
        if collecting:
            out.append(line)
    return "\n".join(out).strip()


def build_story(fields: dict, key: str, points_field: str) -> dict:
    description = acli.issue_description(fields)
    return {
        "key": key,
        "summary": acli.issue_summary(fields),
        "description": description,
        "acs": extract_acs(description),
        "points": acli.story_points(fields, points_field),
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    cfg = config.load_config(Path(args.repo), {})
    fields = acli.fetch_issue(args.key)
    story = build_story(fields, args.key, cfg.story_points_field)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(story, indent=2))
    print(f"resolved {args.key} -> {out} (points={story['points']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
