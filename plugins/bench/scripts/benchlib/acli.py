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


def _flatten_adf(node: Any, out: List[str], depth: int = 0) -> None:
    if isinstance(node, dict):
        node_type = node.get("type")

        # Text node: append literal text
        if node_type == "text":
            out.append(node.get("text", ""))

        # Hard break: single newline within flow
        elif node_type == "hardBreak":
            out.append("\n")

        # List item: special case with marker and depth-based indentation
        elif node_type == "listItem":
            indent = "  " * depth
            out.append(indent + "- ")
            for child in node.get("content", []) or []:
                # Nested lists increment depth
                if isinstance(child, dict) and child.get("type") in ("bulletList", "orderedList"):
                    _flatten_adf(child, out, depth + 1)
                else:
                    _flatten_adf(child, out, depth)
            out.append("\n")

        # Task item: similar to list item with marker and depth-based indentation
        elif node_type == "taskItem":
            indent = "  " * depth
            out.append(indent + "- ")
            for child in node.get("content", []) or []:
                # Nested lists increment depth
                if isinstance(child, dict) and child.get("type") in ("bulletList", "orderedList", "taskList"):
                    _flatten_adf(child, out, depth + 1)
                else:
                    _flatten_adf(child, out, depth)
            out.append("\n")

        # All other container nodes
        else:
            # Pass current depth to children (no increment)
            for child in node.get("content", []) or []:
                _flatten_adf(child, out, depth)

            # Block elements get double newline separator
            if node_type in ("paragraph", "heading", "codeBlock", "bulletList", "orderedList", "taskList"):
                out.append("\n\n")

    elif isinstance(node, list):
        for child in node:
            _flatten_adf(child, out, depth)


def flatten_adf(node: Any) -> str:
    """Flatten an ADF node (or list of nodes) to plain text.

    The single public entry point for ADF -> text in this plugin. It exists
    because there was briefly a second, subtly different flattener in
    resolve.py that dropped list nesting -- flattening a nested
    sub-criterion up to top level, which silently inflated the acceptance
    criteria count and therefore every report's ACs denominator. One
    implementation, one nesting behaviour.
    """
    parts: List[str] = []
    _flatten_adf(node, parts)
    return "".join(parts)


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


# Every issue this harness creates carries this label. Cleanup finds them by
# query rather than by remembering what it made: a crashed sweep still leaves
# findable issues, whereas a remembered list dies with the process that held
# it. The label is also what makes a mis-scoped deletion detectable -- an
# issue without it is not ours and must never be deleted.
BENCH_LABEL = "bench-run"


def issue_type(fields: dict) -> str:
    """The issue type name, or "" if it cannot be read.

    Cloning a Story as a Task changes how the SDLC plugin routes it -- defects
    skip the spec and plan phases entirely -- so a clone that guesses the type
    measures a different lifecycle than the source ticket would have.
    """
    itype = fields.get("issuetype")
    if isinstance(itype, dict):
        return str(itype.get("name") or "")
    return str(itype or "")


def create_issue(
    project: str,
    summary: str,
    description: str,
    issue_type_name: str,
    labels: Optional[List[str]] = None,
) -> str:
    """Create an issue and return its key.

    The description is passed via `--description`, not a temp file: acli
    accepts plain text there, and writing ticket text to disk to read it
    straight back adds a failure mode without removing one.
    """
    labels = list(labels or [])
    if BENCH_LABEL not in labels:
        labels.append(BENCH_LABEL)

    args = [
        "jira",
        "workitem",
        "create",
        "--project",
        project,
        "--type",
        issue_type_name,
        "--summary",
        summary,
        "--description",
        description,
        "--label",
        ",".join(labels),
        "--json",
    ]
    raw = run(args)
    data = seek_json(raw)
    key = None
    if isinstance(data, dict):
        key = data.get("key") or (data.get("issue") or {}).get("key")
    elif isinstance(data, list) and data:
        first = data[0]
        if isinstance(first, dict):
            key = first.get("key")
    if not key:
        raise AcliError(
            "created an issue but could not read its key back from acli's "
            "output. The issue may exist and be untracked -- search {0} for "
            "the `{1}` label before retrying.".format(project, BENCH_LABEL)
        )
    return str(key)


def comment(key: str, body: str) -> None:
    # `--key`, not a positional: `acli jira workitem comment create` takes its
    # targets by flag and silently does nothing useful with a bare argument.
    run(["jira", "workitem", "comment", "create", "--key", key, "--body", body])


def search_by_label(project: str, label: str = BENCH_LABEL) -> List[str]:
    """Keys of every issue in `project` carrying `label`.

    Cleanup's discovery mechanism. JQL rather than a stored list so an issue
    created by a sweep that crashed before recording it is still found.
    """
    jql = 'project = "{0}" AND labels = "{1}"'.format(project, label)
    raw = run(["jira", "workitem", "search", "--jql", jql, "--json"])
    data = seek_json(raw)
    rows = data if isinstance(data, list) else data.get("issues") or []
    keys = []
    for row in rows:
        if isinstance(row, dict) and row.get("key"):
            keys.append(str(row["key"]))
    return keys


def delete_issue(key: str) -> None:
    """Delete one issue. Irreversible.

    Callers must confirm first AND must have checked the issue carries
    BENCH_LABEL -- this function deletes whatever key it is handed, so the
    safety lives at the call site where the label evidence is.
    """
    # `--key`, not a positional. `acli jira workitem delete <KEY> --yes` fails
    # with "at least one of the flags in the group [key from-file jql filter] is
    # required" -- the bare argument is ignored entirely. Same shape as the
    # `comment create` call above.
    #
    # Deliberately one key per call rather than a comma-joined list: --key
    # accepts several, but a partial failure across a batch gives no way to tell
    # which issues died and which survived, and this is the irreversible
    # operation in the harness.
    run(["jira", "workitem", "delete", "--key", key, "--yes"])
