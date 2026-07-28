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
from typing import Any, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import acli, config  # noqa: E402

_AC_HEADING = re.compile(r"^\s*acceptance criteria\s*:?\s*$", re.IGNORECASE)
_NEXT_HEADING = re.compile(
    r"^\s*(non-?goals?|notes?|prerequisites?|out of scope|objective|rollout|dependencies)\s*:?\s*$", re.IGNORECASE
)


def _flatten_adf_nodes(nodes: List[Any]) -> str:
    """Flatten ADF nodes to plain text (minimal formatting)."""
    parts = []
    for node in nodes:
        if isinstance(node, dict):
            node_type = node.get("type")
            if node_type == "text":
                parts.append(node.get("text", ""))
            elif node_type == "hardBreak":
                parts.append("\n")
            elif node_type == "paragraph":
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
                parts.append("\n")
            elif node_type == "heading":
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
                parts.append("\n")
            elif node_type in ("bulletList", "orderedList", "taskList"):
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
            elif node_type == "listItem":
                parts.append("- ")
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
                parts.append("\n")
            elif node_type == "taskItem":
                parts.append("- ")
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
                parts.append("\n")
            elif node_type == "codeBlock":
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
                parts.append("\n")
            else:
                # Generic container: just process children
                for child in node.get("content", []) or []:
                    parts.append(_flatten_adf_nodes([child]))
    return "".join(parts)


def _extract_heading_text(node: Any) -> str:
    """Extract plain text from a heading node."""
    if not isinstance(node, dict) or node.get("type") != "heading":
        return ""
    parts = []
    for child in node.get("content", []) or []:
        if isinstance(child, dict) and child.get("type") == "text":
            parts.append(child.get("text", ""))
    return "".join(parts)


def extract_acs_structural(adf: Any) -> str:
    """Extract acceptance criteria from ADF tree by structural scanning.

    Finds the first heading matching 'acceptance criteria' (case-insensitive),
    then collects sibling nodes until the next heading at the same or higher level.
    Falls back to empty string if no AC heading is found.
    """
    if not isinstance(adf, dict) or adf.get("type") != "doc":
        return ""

    content = adf.get("content", []) or []
    ac_heading_idx = None
    ac_heading_level = None

    # Find the "Acceptance Criteria" heading
    for i, node in enumerate(content):
        if isinstance(node, dict) and node.get("type") == "heading":
            text = _extract_heading_text(node)
            if re.search(r"acceptance\s+criteria", text, re.IGNORECASE):
                ac_heading_idx = i
                ac_heading_level = node.get("attrs", {}).get("level")
                break

    if ac_heading_idx is None:
        return ""

    # Collect nodes from AC heading until next heading at same/higher level
    collected = []
    for i in range(ac_heading_idx + 1, len(content)):
        node = content[i]
        if isinstance(node, dict) and node.get("type") == "heading":
            # Stop if we hit a heading at same or higher (lower number) level
            node_level = node.get("attrs", {}).get("level")
            if node_level is not None and ac_heading_level is not None:
                if node_level <= ac_heading_level:
                    break
        collected.append(node)

    # Flatten collected nodes
    result = _flatten_adf_nodes(collected).strip()
    return result


def extract_acs(description: str) -> str:
    """Extract acceptance criteria from plain text description.

    Used as fallback for plain string descriptions. Scans for a line matching
    'Acceptance criteria' heading and collects following lines until next section.
    """
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
    desc_field = fields.get("description")
    description = acli.issue_description(fields)

    # Try structural extraction if description is ADF dict
    if isinstance(desc_field, dict) and desc_field.get("type") == "doc":
        acs = extract_acs_structural(desc_field)
    else:
        # Fall back to text-based extraction for plain strings
        acs = extract_acs(description)

    return {
        "key": key,
        "summary": acli.issue_summary(fields),
        "description": description,
        "acs": acs,
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
