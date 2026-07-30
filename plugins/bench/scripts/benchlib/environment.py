"""What a measured session actually loads, and what leaks into it anyway.

A benchmark worktree is a fresh checkout of the subject repository, so it
carries that repo's committed `.claude/settings.json`. The operator's
`~/.claude/settings.json` layers on top. Neither is written with a benchmark
in mind, and both enable plugins.

Verified on the machine this was written for: the repo enables `sdlc`, `gtm`,
`superpowers`, `postiz`, `marketing-skills` and `nx`; the user settings add
`caveman`, `claude-mem`, `context-mode` and `typescript-lsp`. A cell labelled
"Direct Opus, no framework" therefore ran with the SDLC plugin's commands
available and with superpowers' SessionStart hook injecting "You have
superpowers" into it. Every approach was measured through the same fog, which
does not make the fog harmless: it makes each label wrong in a different
direction, and it means a sweep repeated on another machine measures something
else entirely.

Two mechanisms are available and this module uses the one that works:

- **Plugins are controllable.** `.claude/settings.local.json` in the worktree
  overrides both the project and user layers. Probed with `claude plugin list`
  (no model call, no spend): a project-local `"caveman@caveman": false`
  flipped a user-scope plugin to disabled. So provision.py writes an explicit
  true/false for every installed plugin and the adapter's declared set is the
  true side.
- **User-level hooks are NOT controllable** from a project settings file --
  hooks merge additively across layers with no override key. Plugin-supplied
  hooks disappear along with their plugins, which removes most of them, but
  whatever remains in `~/.claude/settings.json` runs in every cell. Those are
  recorded verbatim rather than suppressed, so a reader can see the confound
  instead of inferring it. On this machine that is `rtk hook claude`, a
  PreToolUse hook that rewrites shell commands through a token-reducing proxy
  -- which directly moves the number this benchmark exists to measure.
"""
import json
from pathlib import Path
from typing import Dict, List, Optional

INSTALLED_PLUGINS_PATH = Path.home() / ".claude" / "plugins" / "installed_plugins.json"
USER_SETTINGS_PATH = Path.home() / ".claude" / "settings.json"


def _read_json(path: Path) -> Optional[dict]:
    """Read a JSON object, or None if it is absent or unusable.

    A missing or malformed settings file must never abort provisioning: the
    consequence of failing to read one is a slightly over-broad disable list,
    which is the safe direction.
    """
    try:
        data = json.loads(Path(path).read_text())
    except (IOError, OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def installed_plugin_keys(installed_path: Optional[Path] = None) -> List[str]:
    data = _read_json(installed_path or INSTALLED_PLUGINS_PATH) or {}
    plugins = data.get("plugins")
    if not isinstance(plugins, dict):
        return []
    return sorted(str(key) for key in plugins)


def settings_plugin_keys(paths: List[Path]) -> List[str]:
    """Plugin keys named by any settings layer, enabled or not.

    Keys set to `false` still matter: they name a plugin this machine knows
    about, and the point of the disable map is to be exhaustive over names
    rather than over currently-enabled ones.
    """
    keys = set()
    for path in paths:
        data = _read_json(path) or {}
        enabled = data.get("enabledPlugins")
        if isinstance(enabled, dict):
            keys.update(str(key) for key in enabled)
    return sorted(keys)


def known_plugin_keys(
    repo: Path,
    installed_path: Optional[Path] = None,
    user_settings: Optional[Path] = None,
) -> List[str]:
    """Every plugin key this machine could enable in the measured session."""
    settings_paths = [
        user_settings or USER_SETTINGS_PATH,
        Path(repo) / ".claude" / "settings.json",
    ]
    return sorted(
        set(installed_plugin_keys(installed_path)) | set(settings_plugin_keys(settings_paths))
    )


CACHE_ROOT = Path.home() / ".claude" / "plugins" / "cache"


def _version_sort_key(name: str):
    """Order version directory names newest-last, numerically where possible.

    Falls back to string order for non-numeric names (a git sha, "unknown"), so
    a mixed directory still yields a deterministic pick rather than raising.
    """
    parts = []
    for chunk in str(name).replace("-", ".").split("."):
        parts.append((0, int(chunk)) if chunk.isdigit() else (1, chunk))
    return parts


def plugin_dependencies(
    key: str, cache_root: Optional[Path] = None
) -> List[str]:
    """The plugin keys `key` declares as dependencies.

    Read from the plugin's own `.claude-plugin/plugin.json`, whose
    `dependencies` entries are `{name, marketplace}` pairs.

    The NEWEST cached version is read, not the pinned one. Dependency
    declarations are a property of the plugin's identity rather than of a
    particular release, and a pinned version whose directory has been swept
    would otherwise make dependency resolution fail exactly when it matters.
    If a future version genuinely changes its dependencies, the union across
    versions is the safe direction: enabling one plugin too many costs a little
    context, and disabling one costs the entire measurement (see below).
    """
    root = Path(cache_root or CACHE_ROOT)
    if "@" not in key:
        return []
    name, marketplace = key.split("@", 1)
    base = root / marketplace / name
    if not base.is_dir():
        return []
    versions = sorted(
        (d for d in base.iterdir() if d.is_dir()), key=lambda d: _version_sort_key(d.name)
    )
    for version_dir in reversed(versions):
        manifest = version_dir / ".claude-plugin" / "plugin.json"
        data = _read_json(manifest)
        if data is None:
            continue
        out = []
        for dep in data.get("dependencies") or []:
            if isinstance(dep, dict) and dep.get("name") and dep.get("marketplace"):
                out.append("{0}@{1}".format(dep["name"], dep["marketplace"]))
        return out
    return []


def resolve_dependencies(
    declared: List[str], cache_root: Optional[Path] = None
) -> List[str]:
    """`declared` plus every plugin it transitively depends on.

    THIS IS NOT A CONVENIENCE. A plugin whose declared dependency is disabled
    does not merely lose that dependency's features -- it fails to load
    entirely, registering none of its own skills or agents.

    That cost a real benchmark cell. `sdlc@nightshift` declares
    `superpowers@claude-plugins-official` and `claude-mem@thedotmack`; the
    exhaustive disable map wrote `false` for both; the plugin silently did not
    load; and the measured session answered `Unknown skill: sdlc:auto` in 11ms
    having done nothing. Bisected to a single key: re-enabling either
    dependency alone fixed it.

    Callers must treat the extra keys as part of what the approach IS, and say
    so in the report -- an SDLC row necessarily also loads superpowers, so it
    is not independent of the superpowers row.
    """
    seen: List[str] = []
    queue = list(declared)
    while queue:
        key = queue.pop(0)
        if key in seen:
            continue
        seen.append(key)
        for dep in plugin_dependencies(key, cache_root):
            if dep not in seen:
                queue.append(dep)
    return seen


def enabled_plugins_map(
    declared: List[str],
    repo: Path,
    installed_path: Optional[Path] = None,
    user_settings: Optional[Path] = None,
    cache_root: Optional[Path] = None,
) -> Dict[str, bool]:
    """The explicit enabledPlugins map to write into the worktree.

    Exhaustive by construction: every key this machine knows about appears,
    true if the adapter declared it and false otherwise. An omitted key would
    inherit whatever the operator set, which is the leak this exists to close.

    A declared plugin that is not installed is still written as true. Claude
    Code will simply not find it, and that is a louder, more diagnosable
    failure than quietly dropping it and reporting a run that measured an
    approach without the plugin it is named after.

    The true side is the declared set PLUS its transitive dependencies -- see
    resolve_dependencies for why disabling one is fatal rather than merely
    reductive.
    """
    required = resolve_dependencies(declared, cache_root)
    keys = set(known_plugin_keys(repo, installed_path, user_settings)) | set(required)
    return {key: key in required for key in sorted(keys)}


def _hook_commands(data: dict) -> List[Dict[str, str]]:
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return []
    out: List[Dict[str, str]] = []
    for event, matchers in sorted(hooks.items()):
        if not isinstance(matchers, list):
            continue
        for matcher in matchers:
            if not isinstance(matcher, dict):
                continue
            for hook in matcher.get("hooks") or []:
                if isinstance(hook, dict) and hook.get("command"):
                    out.append({"event": str(event), "command": str(hook["command"])})
    return out


def ambient_hooks(
    repo: Path,
    user_settings: Optional[Path] = None,
) -> List[Dict[str, str]]:
    """Hooks that run in the measured session and cannot be turned off.

    Only the user and project settings layers are scanned. Plugin-supplied
    hooks are deliberately excluded: those arrive with their plugin and leave
    with it, so the enabledPlugins map already controls them, and listing them
    here would report a confound that provisioning has in fact removed.
    """
    out: List[Dict[str, str]] = []
    for path in (user_settings or USER_SETTINGS_PATH, Path(repo) / ".claude" / "settings.json"):
        data = _read_json(path)
        if data is None:
            continue
        for hook in _hook_commands(data):
            out.append(dict(hook, source=str(path)))
    return out


def environment_record(
    declared: List[str],
    repo: Path,
    installed_path: Optional[Path] = None,
    user_settings: Optional[Path] = None,
    cache_root: Optional[Path] = None,
) -> Dict[str, object]:
    """What this cell's session runs inside, for the run record.

    Recorded per cell rather than stated once in a doc for the same reason
    billing mode is: a sweep can be repeated on another machine, or on this
    one after the operator installs a plugin or adds a hook. A reader months
    later cannot reconstruct either from the numbers alone.
    """
    plugin_map = enabled_plugins_map(
        declared, repo, installed_path, user_settings, cache_root
    )
    hooks = ambient_hooks(repo, user_settings)
    # Split out so a reader can tell what the approach asked for from what its
    # dependencies dragged in. The distinction decides whether two rows are
    # independent: an approach whose dependency IS another approach cannot be
    # compared against it as though they were separate treatments.
    required = resolve_dependencies(declared, cache_root)
    pulled_in = sorted(set(required) - set(declared))
    return {
        "enabled_plugins": plugin_map,
        "declared_plugins": sorted(declared),
        "dependency_plugins": pulled_in,
        "disabled_plugins": sorted(k for k, v in plugin_map.items() if not v),
        "ambient_hooks": hooks,
        "isolated": True,
        "note": (
            "Plugins are pinned to the adapter's declared set: every other "
            "installed plugin is explicitly disabled in the worktree's "
            "settings.local.json, which overrides both the repository's "
            "committed settings and the operator's user settings. Hooks "
            "declared in those two settings files cannot be overridden from a "
            "project file and run in every cell -- they are listed under "
            "ambient_hooks as a recorded confound, not a suppressed one."
        ),
    }
