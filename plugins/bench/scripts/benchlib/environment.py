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


def enabled_plugins_map(
    declared: List[str],
    repo: Path,
    installed_path: Optional[Path] = None,
    user_settings: Optional[Path] = None,
) -> Dict[str, bool]:
    """The explicit enabledPlugins map to write into the worktree.

    Exhaustive by construction: every key this machine knows about appears,
    true if the adapter declared it and false otherwise. An omitted key would
    inherit whatever the operator set, which is the leak this exists to close.

    A declared plugin that is not installed is still written as true. Claude
    Code will simply not find it, and that is a louder, more diagnosable
    failure than quietly dropping it and reporting a run that measured an
    approach without the plugin it is named after.
    """
    keys = set(known_plugin_keys(repo, installed_path, user_settings)) | set(declared)
    return {key: key in declared for key in sorted(keys)}


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
) -> Dict[str, object]:
    """What this cell's session runs inside, for the run record.

    Recorded per cell rather than stated once in a doc for the same reason
    billing mode is: a sweep can be repeated on another machine, or on this
    one after the operator installs a plugin or adds a hook. A reader months
    later cannot reconstruct either from the numbers alone.
    """
    plugin_map = enabled_plugins_map(declared, repo, installed_path, user_settings)
    hooks = ambient_hooks(repo, user_settings)
    return {
        "enabled_plugins": plugin_map,
        "declared_plugins": sorted(declared),
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
