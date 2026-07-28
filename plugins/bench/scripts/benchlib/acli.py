"""Thin acli wrapper.

Two constraints drive this module, both verified against whimzylive.atlassian.net:

1. acli's --json output is not always pure JSON; a banner line may precede it.
2. `workitem search --fields <customfield>` is rejected outright, so custom fields
   are only readable through `workitem view --fields '*all' --json`, one issue per call.
"""
import json
import subprocess
from typing import Any, List, Optional


class AcliError(RuntimeError):
    pass


def seek_json(raw: str) -> Any:
    """Decode JSON that may be preceded by banner text."""
    candidates = [i for i in (raw.find("{"), raw.find("[")) if i >= 0]
    if not candidates:
        raise ValueError("no JSON object or array found in acli output")
    return json.loads(raw[min(candidates):])


def run(args: List[str]) -> str:
    proc = subprocess.run(["acli"] + args, capture_output=True, text=True)
    if proc.returncode != 0:
        raise AcliError(f"acli {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout


def fetch_issue(key: str) -> dict:
    """Return the fields dict for one issue. Uses '*all' because custom fields
    are unavailable through any narrower field selection."""
    raw = run(["jira", "workitem", "view", key, "--fields", "*all", "--json"])
    return seek_json(raw).get("fields", {})


def issue_summary(fields: dict) -> str:
    return fields.get("summary") or ""


def _flatten_adf(node: Any, out: List[str]) -> None:
    if isinstance(node, dict):
        if node.get("type") == "text":
            out.append(node.get("text", ""))
        for child in node.get("content", []) or []:
            _flatten_adf(child, out)
        if node.get("type") in ("paragraph", "heading"):
            out.append("\n\n")
    elif isinstance(node, list):
        for child in node:
            _flatten_adf(child, out)


def issue_description(fields: dict) -> str:
    desc = fields.get("description")
    if desc is None:
        return ""
    if isinstance(desc, str):
        return desc
    parts: List[str] = []
    _flatten_adf(desc, parts)
    return "".join(parts).strip()


def story_points(fields: dict, field_id: str) -> Optional[float]:
    return fields.get(field_id)
