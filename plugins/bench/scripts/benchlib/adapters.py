"""Declarative approach adapters.

An approach is a YAML file, so adding one needs no code change. Templating is
{{name}} substitution over a fixed variable set — adapter text is never passed
through a shell evaluator.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

import yaml

# A plugin is identified as `<name>@<marketplace>` everywhere Claude Code
# records one. A bare name is ambiguous -- `superpowers` exists in both
# `claude-plugins-official` and `superpowers-marketplace` on this machine at
# different versions -- so an adapter naming one without its marketplace is
# rejected rather than resolved by guesswork.
_PLUGIN_KEY = re.compile(r"^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$")

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
class PluginVersion:
    """A pinned plugin version for an approach that IS a plugin.

    `plugin` is the installed-plugin key (`sdlc@nightshift`); `version` is the
    cache version directory (`0.44.0`). Both are required together: a plugin
    with no version measures whatever happens to be installed, and a version
    with no plugin names nothing.
    """

    plugin: str
    version: str


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
    version: Optional[PluginVersion] = None
    # The EXACT plugin set this approach is. Not "extra plugins to add" --
    # the complete list, because provision.py explicitly disables every
    # installed plugin absent from it. See `load_plugins` for why an empty
    # list must be spelled out rather than left off.
    plugins: List[str] = field(default_factory=list)
    permissions: List[str] = field(default_factory=list)
    # Whether this approach needs a Jira issue of its OWN to work against,
    # supplied per cell via provision.py's --twin-ticket.
    #
    # True only for approaches that WRITE to Jira. The SDLC plugin comments,
    # transitions and links PRs on its story, and derives its git branch from
    # the story key -- so two SDLC cells sharing one issue also share one
    # branch, and its playbook reuses an existing `feat/<KEY>` branch rather
    # than creating a duplicate. The second cell would check out the first
    # cell's finished work and measure nothing.
    #
    # The harness does NOT create these. acli cannot write custom fields on
    # this build -- no --custom flag, `additionalAttributes` rejected as an
    # unknown field, and `clone` copies summary, description, labels and type
    # but not story points (all three tested). A cloned issue therefore arrives
    # with points unset, and /sdlc:auto triages on points: the cell would take
    # the lightweight path while the report labelled it the full lifecycle. So
    # the operator creates pointed twins by hand and names one per cell.
    #
    # Approaches that only READ the ticket text (they receive it in the prompt)
    # leave this false: an issue nobody writes to is noise to require.
    dedicated_ticket: bool = False

    @property
    def cell_id(self) -> str:
        """The identity this adapter's cells are filed under.

        Version-pinned approaches must not collide: artifacts live at
        `docs/benchmarks/<ticket>/<cell_id>/artifacts` with no run_id in the
        path, so two versions sharing a cell id would have the second
        overwrite the first's test evidence and report row.
        """
        if self.version is None:
            return self.id
        return "{0}@{1}".format(self.id, self.version.version)


def load_version(raw, path: Path) -> Optional[PluginVersion]:
    """Parse an adapter's optional `version:` block.

    Absent is legitimate and common: an approach that is not a plugin (direct
    Opus) has no version to pin. What is NOT legitimate is a half-declared
    block -- that reads as a pin to anyone skimming the file while measuring
    whatever version is installed, so it is rejected rather than ignored.
    """
    if raw is None:
        return None
    if not isinstance(raw, dict):
        raise ValueError(
            "adapter {0} has a `version:` that is not a mapping. Expected "
            "`version: {{plugin: <name>@<marketplace>, version: <x.y.z>}}`.".format(path)
        )

    plugin = str(raw.get("plugin") or "").strip()
    version = str(raw.get("version") or "").strip()
    missing = [
        name for name, value in (("plugin", plugin), ("version", version)) if not value
    ]
    if missing:
        raise ValueError(
            "adapter {0} has a `version:` block missing required key(s): {1}. A "
            "partially declared pin looks like a pinned run but measures whatever "
            "version happens to be installed.".format(path, ", ".join(missing))
        )

    return PluginVersion(plugin=plugin, version=version)


def load_plugins(raw, path: Path) -> List[str]:
    """Parse the REQUIRED `plugins.enable` block.

    This is required, and an approach that loads no plugins must say
    `enable: []` rather than omit the block, because omission and emptiness
    mean opposite things here. A benchmark worktree is a checkout of the
    subject repository, so it carries that repo's committed
    `.claude/settings.json`; the operator's `~/.claude/settings.json` adds
    more on top. Left alone, a cell labelled "no framework" runs with every
    plugin the operator happens to have enabled -- on the machine this was
    written for, that meant the SDLC plugin, superpowers (whose SessionStart
    hook injects "You have superpowers" into the very session meant to have
    none), and four others. The label would be a claim the measurement
    contradicts.

    So provision.py writes an explicit true/false for EVERY installed
    plugin, and this list is the true side. Requiring it makes the plugin
    set a deliberate statement per approach rather than a property of
    whoever ran the sweep.
    """
    if raw is None:
        raise ValueError(
            "adapter {0} has no `plugins:` block. Declare the exact plugin set "
            "this approach loads -- `plugins: {{enable: []}}` for an approach "
            "that loads none. Omitting it would let the operator's own enabled "
            "plugins leak into the measured session, so there is no safe "
            "default to assume.".format(path)
        )
    if not isinstance(raw, dict) or "enable" not in raw:
        raise ValueError(
            "adapter {0} has a `plugins:` block without an `enable:` key. "
            "Expected `plugins: {{enable: [<name>@<marketplace>, ...]}}`.".format(path)
        )

    enable = raw["enable"]
    if enable is None:
        enable = []
    if not isinstance(enable, list):
        raise ValueError(
            "adapter {0} has a `plugins.enable` that is not a list: {1!r}.".format(
                path, enable
            )
        )

    keys = []
    for entry in enable:
        key = str(entry).strip()
        if not _PLUGIN_KEY.match(key):
            raise ValueError(
                "adapter {0} names plugin {1!r}, which is not in "
                "`<name>@<marketplace>` form. A bare name is ambiguous: the "
                "same plugin name can exist in two marketplaces at different "
                "versions.".format(path, entry)
            )
        if key in keys:
            raise ValueError(
                "adapter {0} lists plugin {1!r} twice.".format(path, key)
            )
        keys.append(key)
    return keys


def load_permissions(raw, path: Path) -> List[str]:
    """Parse the optional `permissions.allow` block.

    Grants an approach the tools it genuinely needs to perform its own
    behaviour -- spec-kit cannot run without `uv` and `specify`, and the
    SDLC plugin cannot run without `acli` and `gh`. These are per-approach
    because granting every approach every tool would let one approach's
    requirements silently widen another's blast radius.

    Allow entries only. The deny list in provision.py is not adapter-settable:
    an adapter that could deny nothing could also un-deny `git push`, and the
    bench/ branch boundary is not an approach's decision to make.
    """
    if raw is None:
        return []
    # A bare list is the common case and reads better in the YAML, since
    # `allow` is the only thing an adapter may set. `permissions: {allow: []}`
    # stays valid so the block matches how Claude Code itself spells it.
    if isinstance(raw, list):
        return [str(entry) for entry in raw]
    if not isinstance(raw, dict):
        raise ValueError(
            "adapter {0} has a `permissions:` that is neither a list nor a "
            "mapping. Expected `permissions: [...]` or "
            "`permissions: {{allow: [...]}}`.".format(path)
        )
    unknown = sorted(set(raw) - {"allow"})
    if unknown:
        raise ValueError(
            "adapter {0} has unsupported `permissions:` key(s): {1}. Only "
            "`allow` is adapter-settable -- the deny list is a harness "
            "boundary, not an approach's choice.".format(path, ", ".join(unknown))
        )

    allow = raw.get("allow") or []
    if not isinstance(allow, list):
        raise ValueError(
            "adapter {0} has a `permissions.allow` that is not a list: "
            "{1!r}.".format(path, allow)
        )
    return [str(entry) for entry in allow]


def assert_version_plugin_enabled(
    version: Optional[PluginVersion], plugins: List[str], path: Path
) -> None:
    """A pinned plugin must be one this approach actually enables.

    Otherwise the cell pins version 0.44.0 of a plugin it then explicitly
    disables: the pin is applied, the transcript shows no plugin root
    because the plugin never loads, and the row is filed under a version
    that contributed nothing to the session.
    """
    if version is None:
        return
    if version.plugin not in plugins:
        raise ValueError(
            "adapter {0} pins {1} at {2} but does not list it in "
            "`plugins.enable` ({3}). The pin would be applied to a plugin the "
            "cell then disables, so the row would be labelled with a version "
            "that never loaded.".format(
                path,
                version.plugin,
                version.version,
                ", ".join(plugins) or "empty",
            )
        )


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

    if "scratch_ticket" in data:
        raise ValueError(
            "adapter {0} uses `scratch_ticket:`, which no longer exists. It "
            "meant 'clone an issue for me', and the harness cannot do that "
            "usefully: acli cannot set story points on a clone, so the clone "
            "triages down the wrong path. Rename it to `dedicated_ticket:` and "
            "pass the pre-pointed twin per cell with --twin-ticket.".format(path)
        )

    version = load_version(data.get("version"), path)
    plugin_keys = load_plugins(data.get("plugins"), path)
    assert_version_plugin_enabled(version, plugin_keys, path)

    return Adapter(
        version=version,
        plugins=plugin_keys,
        permissions=load_permissions(data.get("permissions"), path),
        dedicated_ticket=bool(data.get("dedicated_ticket")),
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
