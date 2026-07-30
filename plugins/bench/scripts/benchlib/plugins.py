"""Pin a benchmark cell's session to a specific plugin version.

Why this module exists at all
-----------------------------
Claude Code resolves an installed plugin's version per PROJECT PATH, not per
branch and not per repository. ``~/.claude/plugins/installed_plugins.json``
maps ``<plugin>@<marketplace>`` to a list of entries, each keyed by
``projectPath`` and carrying the ``installPath`` that session will load.
``.claude/settings.json`` enables plugins by name only -- it carries no
version -- so checking out a different branch, or a different commit, changes
nothing about which version of a plugin the measured session runs.

That makes the naive approach to "benchmark 0.44.0 against 0.45.4" -- run the
two cells on two branches -- measure the same plugin twice. The lever that
does work is the project path, and every bench cell already has its own: the
worktree.

Two behaviours observed on a real machine drive the design here:

1. A session started in a path with no entry gets one AUTO-CREATED, and doing
   so REPLACED the parent repository's entry rather than sitting alongside it.
   A bench cell would therefore silently repoint the operator's own repo to a
   different plugin version, mid-session, while they are working in it. So the
   entry is pre-seeded BEFORE the session starts (no auto-create ever runs),
   and the whole file is snapshotted and restored afterwards.

2. The plugin cache reference-counts (``.in_use``) and marks unreferenced
   versions (``.orphaned_at``, swept per ``.last_inuse_sweep``). A version that
   nothing points at can be garbage-collected. A benchmark baseline recorded
   months ago may simply no longer exist on disk, so a pin whose target is
   missing must fail loudly at preflight rather than silently fall through to
   whatever version happens to be installed.

Nothing in this module writes a credential, and nothing it writes leaves the
operator's machine.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Tuple

CACHE_ROOT = Path.home() / ".claude" / "plugins" / "cache"
INSTALLED_PLUGINS_PATH = Path.home() / ".claude" / "plugins" / "installed_plugins.json"


class PluginPinError(RuntimeError):
    """Raised when a version pin cannot be honoured exactly as declared.

    Never downgraded to a warning: a pin that quietly does not apply produces
    a benchmark row labelled with a version it did not measure, which is the
    one failure mode this whole feature exists to prevent.
    """


def parse_plugin_key(key: str) -> Tuple[str, str]:
    """Split ``sdlc@nightshift`` into ``("sdlc", "nightshift")``.

    The marketplace half is the cache's top-level directory, so a malformed
    key would otherwise resolve to a plausible-looking path that does not
    exist.
    """
    if not isinstance(key, str) or key.count("@") != 1:
        raise PluginPinError(
            "plugin key must be exactly '<plugin>@<marketplace>' "
            "(e.g. sdlc@nightshift), got: {0!r}".format(key)
        )
    plugin, marketplace = key.split("@", 1)
    if not plugin or not marketplace:
        raise PluginPinError(
            "plugin key must have a non-empty plugin and marketplace, got: {0!r}".format(key)
        )
    return plugin, marketplace


def install_path(key: str, version: str, cache_root: Optional[Path] = None) -> Path:
    """Where the cache holds a given version of a given plugin."""
    plugin, marketplace = parse_plugin_key(key)
    root = Path(cache_root) if cache_root is not None else CACHE_ROOT
    return root / marketplace / plugin / version


def plugin_dir(key: str, cache_root: Optional[Path] = None) -> Path:
    """The directory holding every cached version of one plugin."""
    plugin, marketplace = parse_plugin_key(key)
    root = Path(cache_root) if cache_root is not None else CACHE_ROOT
    return root / marketplace / plugin


def available_versions(key: str, cache_root: Optional[Path] = None) -> List[str]:
    """Versions of this plugin currently present in the cache, sorted."""
    path = plugin_dir(key, cache_root)
    if not path.is_dir():
        return []
    return sorted(child.name for child in path.iterdir() if child.is_dir())


def assert_version_available(
    key: str, version: str, cache_root: Optional[Path] = None
) -> Path:
    """Resolve a pin target, or fail naming what IS available.

    The cache garbage-collects unreferenced versions, so "the version you
    benchmarked last quarter is gone" is an ordinary outcome, not an exotic
    one. The error lists what remains so the operator can pick a real
    comparison point instead of guessing.
    """
    target = install_path(key, version, cache_root)
    if target.is_dir():
        return target

    present = available_versions(key, cache_root)
    if present:
        detail = "versions present in the cache: {0}".format(", ".join(present))
    else:
        detail = (
            "no versions of this plugin are present in the cache at all "
            "(checked {0})".format(target.parent)
        )
    raise PluginPinError(
        "cannot pin {0} to version {1}: {2} does not exist. The plugin cache "
        "garbage-collects versions nothing references, so a version measured "
        "previously may since have been swept. {3}".format(
            key, version, target, detail
        )
    )


def read_snapshot(path: Optional[Path] = None) -> Optional[str]:
    """Capture installed_plugins.json verbatim, or None if it does not exist.

    Returned as raw text rather than parsed JSON so that restoring is
    byte-for-byte: re-serialising parsed JSON would silently rewrite key
    order and formatting in a file this harness does not own.
    """
    target = Path(path) if path is not None else INSTALLED_PLUGINS_PATH
    try:
        return target.read_text()
    except (IOError, OSError):
        return None


def restore_snapshot(snapshot: Optional[str], path: Optional[Path] = None) -> None:
    """Put installed_plugins.json back exactly as it was.

    A None snapshot means the file did not exist before this run, so the
    correct restore is removal -- leaving a harness-authored file behind
    would pin the operator's paths to whatever the last cell used.
    """
    target = Path(path) if path is not None else INSTALLED_PLUGINS_PATH
    if snapshot is None:
        try:
            target.unlink()
        except (IOError, OSError):
            pass
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(snapshot)


SNAPSHOT_PATH = Path.home() / ".claude" / "plugins" / ".bench-restore.json"


def write_durable_snapshot(snapshot, path: Optional[Path] = None) -> Path:
    """Persist the pre-run installed_plugins.json so a KILLED run can be undone.

    execute.py restores from a snapshot held in memory inside a `finally`. That
    covers an exception and a clean exit; it does NOT cover the process being
    killed, and a benchmark cell is a long-running job an operator will
    reasonably interrupt.

    That gap did real damage: an interrupted cell left 24 auto-created entries
    behind AND the measured session had already REPLACED the parent repository's
    own entries -- so the operator's main repo lost its plugin registrations,
    superpowers silently fell back from 6.2.0 to a user-scope 6.1.1, and
    context-mode from 1.0.162 to 1.0.103. None of it was visible without
    reading the file.

    So the snapshot goes to disk before the pin is applied, and provisioning
    sweeps it on the next run. A file, not a lock: the point is that recovery
    survives the process that created it.
    """
    target = Path(path or SNAPSHOT_PATH)
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "note": (
            "Pre-run copy of installed_plugins.json, written by the bench "
            "harness before it pinned a plugin version. If this file exists, a "
            "benchmark cell did not reach its restore step -- most likely it "
            "was killed. `content` is the byte-for-byte original; null means "
            "the file did not exist before the run."
        ),
        "content": snapshot,
    }
    target.write_text(json.dumps(payload, indent=2) + "\n")
    return target


def clear_durable_snapshot(path: Optional[Path] = None) -> None:
    """Drop the snapshot once the in-memory restore has succeeded."""
    target = Path(path or SNAPSHOT_PATH)
    try:
        target.unlink()
    except (IOError, OSError):
        # Its absence is the desired end state; failing to remove it only
        # means the next run reports a stale recovery, never data loss.
        pass


def recover_if_abandoned(
    installed_path: Optional[Path] = None, snapshot_path: Optional[Path] = None
) -> Optional[str]:
    """Undo an abandoned run's pin. Returns a message, or None if nothing to do.

    Called at provision time rather than execute time: by the time a cell is
    executing it has already pinned, and a stale snapshot from a previous run
    would be indistinguishable from its own.
    """
    snap = Path(snapshot_path or SNAPSHOT_PATH)
    if not snap.is_file():
        return None
    try:
        payload = json.loads(snap.read_text())
    except (IOError, OSError, ValueError):
        return (
            "found an unreadable {0}; leaving installed_plugins.json alone. "
            "Check it by hand -- a previous benchmark cell may have left a "
            "version pin applied.".format(snap)
        )

    restore_snapshot(payload.get("content"), installed_path)
    captured = payload.get("captured_at", "an earlier run")
    clear_durable_snapshot(snap)
    return (
        "recovered: a benchmark cell from {0} was interrupted before it could "
        "restore installed_plugins.json. Its pre-run state has been put back "
        "and the recovery marker cleared.".format(captured)
    )


def pin_entry(data: dict, key: str, project_path: str, target: Path, version: str) -> dict:
    """Return ``data`` with ``project_path`` pinned to ``version``.

    Pure: the caller decides when to write. An existing entry for the same
    path is rewritten in place (preserving its other fields) rather than
    duplicated -- two entries for one path would leave which one wins up to
    Claude Code's resolution order, which is not something a measurement
    should depend on.

    A NEW entry is prepended, not appended, and that ordering is load-bearing.
    Resolution honours array order, and a user-scope install carries an EMPTY
    projectPath which behaves as a wildcard matching every project. Appending
    after such an entry means the pin is written, looks correct in the file,
    and never takes effect.

    Demonstrated, not theorised: pinning superpowers 6.2.0 for a project whose
    array already held a user-scope 6.1.1 entry produced a correct-looking
    6.2.0 entry while `claude plugin details` kept resolving 6.1.1. Moving the
    entry to the front flipped it to 6.2.0 with no other change. Every plugin
    with a user-scope install -- superpowers, caveman, claude-mem,
    context-mode, typescript-lsp on this machine -- is exposed to this, so an
    appended pin would silently measure the wrong version for exactly the
    approaches most likely to be benchmarked.
    """
    out = dict(data or {})
    plugins = dict(out.get("plugins") or {})
    entries = [dict(e) for e in (plugins.get(key) or [])]

    now = datetime.now(timezone.utc).isoformat()
    for index, entry in enumerate(entries):
        if entry.get("projectPath") == project_path:
            entry["installPath"] = str(target)
            entry["version"] = version
            entry["lastUpdated"] = now
            # Rewriting in place is not enough if the existing entry sits
            # behind a wildcard; move it to the front too.
            entries.insert(0, entries.pop(index))
            break
    else:
        entries.insert(
            0,
            {
                "scope": "project",
                "projectPath": project_path,
                "installPath": str(target),
                "version": version,
                "installedAt": now,
                "lastUpdated": now,
            },
        )

    plugins[key] = entries
    out["plugins"] = plugins
    return out


def apply_pin(
    key: str,
    version: str,
    project_path: str,
    installed_path: Optional[Path] = None,
    cache_root: Optional[Path] = None,
) -> dict:
    """Pre-seed the entry for ``project_path`` and write it out.

    Pre-seeding rather than letting Claude Code auto-create is the whole
    point: auto-creation was observed to replace the parent repository's
    entry, so the window in which the operator's own repo is repointed never
    opens if the entry already exists.

    Returns a provenance record for result.json.
    """
    target = assert_version_available(key, version, cache_root)
    path = Path(installed_path) if installed_path is not None else INSTALLED_PLUGINS_PATH

    snapshot = read_snapshot(path)
    try:
        data = json.loads(snapshot) if snapshot else {}
    except ValueError:
        raise PluginPinError(
            "{0} is not valid JSON, so a version pin cannot be applied without "
            "risking the operator's plugin installation. Fix or remove the file "
            "and re-run.".format(path)
        )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(pin_entry(data, key, project_path, target, version), indent=2))

    return {
        "plugin": key,
        "version": version,
        "install_path": str(target),
        "project_path": project_path,
        "installed_plugins_path": str(path),
    }
