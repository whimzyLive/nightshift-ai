"""Declarative approach adapters.

An approach is a YAML file, so adding one needs no code change. Templating is
{{name}} substitution over a fixed variable set — adapter text is never passed
through a shell evaluator.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List

import yaml

ALLOWED_VARS = {
    "ticket_key",
    "ticket_summary",
    "ticket_description",
    "ticket_acs",
    "worktree",
    "artifacts",
    "base_branch",
    "test_command",
}

_VAR = re.compile(r"\{\{(\w+)\}\}")


@dataclass
class Phase:
    id: str
    marker: str


@dataclass
class Adapter:
    id: str
    label: str
    prompt: str
    setup: List[str] = field(default_factory=list)
    flags: List[str] = field(default_factory=list)
    phases: List[Phase] = field(default_factory=list)
    teardown: List[str] = field(default_factory=list)


def load_adapter(path: Path) -> Adapter:
    data = yaml.safe_load(Path(path).read_text()) or {}
    run = data.get("run") or {}
    prompt = run.get("prompt")
    if not prompt:
        raise ValueError(f"adapter {path} has no run.prompt")

    phases = [Phase(id=p["id"], marker=p.get("marker", "")) for p in data.get("phases") or []]
    if not phases:
        phases = [Phase(id="impl", marker="")]

    return Adapter(
        id=data.get("id") or Path(path).stem,
        label=data.get("label") or data.get("id") or Path(path).stem,
        prompt=prompt,
        setup=list(data.get("setup") or []),
        flags=list(run.get("flags") or []),
        phases=phases,
        teardown=list(data.get("teardown") or []),
    )


def render(template: str, variables: Dict[str, str]) -> str:
    def replace(match):
        name = match.group(1)
        if name not in ALLOWED_VARS:
            raise ValueError(f"unknown adapter variable: {name}")
        return str(variables.get(name, ""))

    return _VAR.sub(replace, template)
