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
from typing import Dict, Tuple

CONTEXT_PATH = Path(".claude") / "project" / "project-context.md"
DEFAULT_STORY_POINTS_FIELD = "customfield_10016"

_ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|")

# The project-context row is a PAIR -- `<typecheck> / <test>` -- not one
# command. Either side may be a dash placeholder meaning "this project has
# none". Reading the whole cell as a command yields the literal string
# "— / pnpm nx run-many -t test", which is not runnable: interpolated into a
# shell it errors, and with `|| true` that shell error becomes the "Test
# output" every grader reads. Parse the pair, expose the sides separately.
_PAIR_SEPARATOR = " / "

# Placeholder spellings that mean "no command for this side". Compared
# case-insensitively against the stripped cell half.
_NONE_TOKENS = frozenset({"", "-", "--", "---", "—", "–", "none", "n\\a", "tbd"})

# A command must begin with a program token: letters/digits and the handful
# of punctuation characters a real executable path uses. This rejects the
# dash placeholders, prose, and markdown leftovers -- not a full shell
# grammar, just enough to refuse obviously non-runnable text before a cell
# spends money.
_COMMAND_SHAPE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.:@/\\+-]*(\s|$)")


class InvalidCommandError(RuntimeError):
    """A configured command is missing or does not look like a command."""


@dataclass
class BenchConfig:
    repo_root: Path
    jira_site: str
    jira_project: str
    base_branch: str
    typecheck_command: str
    test_command: str
    package_manager: str
    story_points_field: str


def _clean_command_half(part: str) -> str:
    text = (part or "").strip()
    return "" if text.lower() in _NONE_TOKENS else text


def split_command_pair(value: str) -> Tuple[str, str]:
    """Split a `<typecheck> / <test>` project-context cell into its two sides.

    Returns (typecheck_command, test_command); a side that is absent or a
    dash placeholder comes back as "". A cell with no ` / ` separator is one
    command, and it is the TEST command -- that is what the single-value form
    has always meant to this harness, and the test command is the one every
    downstream consumer actually runs.
    """
    if not value:
        return ("", "")
    if _PAIR_SEPARATOR in value:
        left, right = value.split(_PAIR_SEPARATOR, 1)
        return (_clean_command_half(left), _clean_command_half(right))
    return ("", _clean_command_half(value))


def require_command(command: str, label: str, source: str = "project-context.md") -> str:
    """Return `command`, or raise InvalidCommandError explaining why it is unusable.

    Called BEFORE a cell spends money. A benchmark that runs a session and
    then hands a grader a shell error as its "test output" has burned real
    spend to produce a verdict about nothing; failing here costs nothing.
    """
    text = (command or "").strip()
    if not text:
        raise InvalidCommandError(
            "no {0} command configured (source: {1}). "
            "A benchmark cell cannot produce test evidence without one.".format(label, source)
        )
    if "\n" in text:
        raise InvalidCommandError(
            "{0} command spans multiple lines, which is not a single command: {1!r}".format(
                label, text
            )
        )
    if not _COMMAND_SHAPE.match(text):
        raise InvalidCommandError(
            "{0} command does not look like a command (source: {1}): {2!r}".format(
                label, source, text
            )
        )
    return text


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

    typecheck_command, test_command = split_command_pair(parsed.get("Typecheck / Test", ""))
    if overrides.get("typecheck_command"):
        typecheck_command = overrides["typecheck_command"]
    if overrides.get("test_command"):
        test_command = overrides["test_command"]

    return BenchConfig(
        repo_root=repo_root,
        jira_site=pick("jira_site", "Jira site", ""),
        jira_project=pick("jira_project", "Jira project key", ""),
        base_branch=pick("base_branch", "Base branch", "main"),
        typecheck_command=typecheck_command,
        test_command=test_command,
        package_manager=pick("package_manager", "Package manager", "npm"),
        story_points_field=pick(
            "story_points_field", "Story points field", DEFAULT_STORY_POINTS_FIELD
        ),
    )
