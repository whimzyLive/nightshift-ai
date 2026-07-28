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
    model: str = ""
    setup: List[str] = field(default_factory=list)
    flags: List[str] = field(default_factory=list)
    phases: List[Phase] = field(default_factory=list)
    teardown: List[str] = field(default_factory=list)


def load_adapter(path: Path) -> Adapter:
    data = yaml.safe_load(Path(path).read_text()) or {}

    if not isinstance(data, dict):
        raise ValueError(f"adapter {path} must be a YAML mapping, not {type(data).__name__}")

    run = data.get("run") or {}
    prompt = run.get("prompt")
    if not prompt:
        raise ValueError(f"adapter {path} has no run.prompt")

    # `run.model` is REQUIRED and part of the adapter contract. Without it
    # execute.py passes no --model and the session runs on whatever the
    # operator's default happens to be -- so a row labelled "Direct Opus"
    # measures an unknown model, and the label is a claim the data does not
    # support. An approach that deliberately does not pin a model must say
    # so explicitly rather than by omission.
    model = run.get("model")
    if not model:
        raise ValueError(
            f"adapter {path} has no run.model. Every adapter must name the model it "
            f"runs, so the report row is labelled honestly rather than measuring the "
            f"operator's default."
        )

    phases_data = data.get("phases") or []
    phases = []
    for i, p in enumerate(phases_data):
        if "id" not in p:
            raise ValueError(f"adapter {path} phase {i} missing required key 'id'")
        phases.append(Phase(id=p["id"], marker=p.get("marker", "")))

    if not phases:
        phases = [Phase(id="impl", marker="")]

    return Adapter(
        id=data.get("id") or Path(path).stem,
        label=data.get("label") or data.get("id") or Path(path).stem,
        prompt=prompt,
        model=model,
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
        if name not in variables:
            raise ValueError(f"adapter variable {name} not provided")
        return str(variables[name])

    return _VAR.sub(replace, template)
