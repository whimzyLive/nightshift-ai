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
    """Extract key/value pairs from the markdown tables in project-context.md."""
    out: Dict[str, str] = {}
    for line in text.splitlines():
        match = _ROW.match(line.strip())
        if not match:
            continue
        key, value = match.group(1).strip(), match.group(2).strip()
        if not key or key == "Token" or set(key) <= set("- "):
            continue
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
