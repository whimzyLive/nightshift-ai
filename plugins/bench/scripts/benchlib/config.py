"""Bench configuration.

Precedence: explicit overrides, then .claude/project/project-context.md, then defaults.

story_points_field has no discovery route. `acli jira field` exposes create/delete/update/
restore but no list, and `workitem view --json` carries no names map, so a field name cannot
be resolved to an ID on an arbitrary site. It is configuration, with Jira Cloud's usual
default as the fallback.
"""
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict

CONTEXT_PATH = Path(".claude") / "project" / "project-context.md"
DEFAULT_STORY_POINTS_FIELD = "customfield_10016"

_ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|")


@dataclass
class BenchConfig:
    repo_root: Path
    jira_site: str
    jira_project: str
    base_branch: str
    test_command: str
    package_manager: str
    story_points_field: str


def parse_project_context(text: str) -> Dict[str, str]:
    """Extract key/value pairs from Token/Value markdown tables only."""
    out: Dict[str, str] = {}
    lines = text.splitlines()
    in_config_table = False

    for line in lines:
        stripped = line.strip()

        # Check if this line is a table row
        match = _ROW.match(stripped)
        if not match:
            # If we were in a config table, check if this ends the table
            if in_config_table and stripped and not stripped.startswith("|"):
                in_config_table = False
            continue

        key, value = match.group(1).strip(), match.group(2).strip()

        # Detect if this is the Token/Value header
        if key == "Token" and value == "Value":
            in_config_table = True
            continue

        # Skip rows if not in a config table
        if not in_config_table:
            continue

        # Skip separator rows (all dashes/spaces)
        if not key or set(key) <= set("- "):
            continue
        # Skip separator values
        if set(value) <= set("- ") and value:
            continue

        out.setdefault(key, value)

    return out


def load_config(repo_root: Path, overrides: Dict[str, str]) -> BenchConfig:
    repo_root = Path(repo_root)
    context_file = repo_root / CONTEXT_PATH
    parsed = parse_project_context(context_file.read_text()) if context_file.exists() else {}

    def pick(override_key: str, context_key: str, default: str) -> str:
        if overrides.get(override_key):
            return overrides[override_key]
        return parsed.get(context_key) or default

    return BenchConfig(
        repo_root=repo_root,
        jira_site=pick("jira_site", "Jira site", ""),
        jira_project=pick("jira_project", "Jira project key", ""),
        base_branch=pick("base_branch", "Base branch", "main"),
        test_command=pick("test_command", "Typecheck / Test", ""),
        package_manager=pick("package_manager", "Package manager", "npm"),
        story_points_field=pick(
            "story_points_field", "Story points field", DEFAULT_STORY_POINTS_FIELD
        ),
    )
