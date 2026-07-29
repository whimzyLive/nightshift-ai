#!/usr/bin/env python3
"""PreToolUse guard for a benchmark cell's Bash commands.

The harness cannot both let an approach perform its real behaviour and keep
`git push` blanket-denied. The SDLC plugin's lifecycle ends at a pull request,
so denying push measures a blocked session rather than the approach. This
replaces the blanket deny with a narrow one: pushes are allowed to the refs
this cell owns and to nothing else.

It is a SECURITY BOUNDARY, so it fails closed in every direction:

* A governed verb it cannot parse with confidence is denied, not allowed.
* A missing or malformed guard config is denied -- a cell whose boundary
  cannot be read has no boundary.
* An unreadable current branch is denied.
* Any unexpected exception is denied (see `main`).

Denials are returned with a reason. That matters: a PreToolUse deny reason is
fed back to the model, so `gh pr create` without `--draft` comes back as an
instruction to retry with `--draft` rather than as an unexplained failure. The
guard shapes behaviour instead of only stopping it.

Registered per worktree by provision.py, which also writes the config it
reads. It is deliberately not a repo-wide hook: its allow-list is per cell.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

CONFIG_NAME = "bench-guard.json"

# Shell constructs that make a single-command parse unreliable. A governed
# verb hiding behind any of these is denied rather than guessed at: with
# `git status && git push origin develop`, naive parsing sees `git status`.
_UNPARSEABLE = ("&&", "||", ";", "|", "`", "$(", "\n")

# Push flags that either bypass the ref allow-list or destroy history. Denied
# unconditionally -- no benchmark needs any of them.
_FORBIDDEN_PUSH_FLAGS = {
    "-f",
    "--force",
    "--force-with-lease",
    "--force-if-includes",
    "--mirror",
    "--all",
    "--tags",
    "--delete",
    "--prune",
}

# Refs no run may write, whatever the cell's allow-list says. Belt to the
# allow-list's braces: a config naming `develop` still cannot push to it.
_NEVER = {"main", "master", "develop", "HEAD"}


class GuardError(RuntimeError):
    """Raised for any condition that must deny. Never allows by falling through."""


def find_config(cwd: str) -> dict:
    """Load the cell's guard config, walking up from the session's cwd.

    Walks up because a session legitimately changes directory inside its
    worktree. Stops at the filesystem root and raises rather than defaulting:
    "no config found" must never read as "nothing to guard".
    """
    here = Path(cwd or ".").resolve()
    for directory in [here] + list(here.parents):
        candidate = directory / ".claude" / CONFIG_NAME
        if candidate.is_file():
            try:
                data = json.loads(candidate.read_text())
            except (IOError, OSError, ValueError) as exc:
                raise GuardError(
                    "benchmark guard config at {0} is unreadable ({1}), so this "
                    "cell has no enforceable ref boundary.".format(candidate, exc)
                )
            if not isinstance(data, dict) or not data.get("allowed_refs"):
                raise GuardError(
                    "benchmark guard config at {0} declares no allowed_refs, so "
                    "no push can be authorised.".format(candidate)
                )
            return data
    raise GuardError(
        "no .claude/{0} found at or above {1}. This hook only runs inside a "
        "provisioned benchmark worktree; without its config there is no ref "
        "allow-list to check against.".format(CONFIG_NAME, here)
    )


def ref_allowed(ref: str, allowed: List[str]) -> bool:
    """Whether one destination ref may be written.

    Patterns are anchored regexes built by provision.py, never operator input.
    A trailing `refs/heads/` prefix is stripped first so `refs/heads/bench/x`
    and `bench/x` are judged identically -- otherwise a fully-qualified
    refspec would slip past a short-form allow-list.
    """
    name = ref.strip()
    for prefix in ("refs/heads/", "+refs/heads/"):
        if name.startswith(prefix):
            name = name[len(prefix) :]
    name = name.lstrip("+")
    if not name or name in _NEVER:
        return False
    return any(re.match(pattern + r"\Z", name) for pattern in allowed)


def current_branch(cwd: str) -> str:
    proc = subprocess.run(
        ["git", "-C", cwd or ".", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise GuardError(
            "cannot determine the current branch in {0}, so a push with no "
            "explicit refspec cannot be checked.".format(cwd)
        )
    return proc.stdout.strip()


def push_destinations(args: List[str], cwd: str) -> List[str]:
    """The refs a `git push` would write.

    A bare `git push` or `git push origin` writes the current branch, which
    the command text does not name -- so it is read from the worktree rather
    than assumed. `src:dst` refspecs are resolved to their destination, since
    that is the ref that actually gets written.
    """
    # Everything after the `push` verb that is not a flag. Slicing from a
    # fixed index instead would count `git` and `push` themselves as the
    # remote and the first refspec, so `git push origin <cell-branch>` would
    # be read as pushing a ref literally named "push".
    try:
        verb = args.index("push")
    except ValueError:
        verb = 1
    positionals = [a for a in args[verb + 1 :] if not a.startswith("-")]
    # The first positional is the remote; what remains are refspecs.
    refspecs = positionals[1:]
    if not refspecs:
        return [current_branch(cwd)]
    out = []
    for spec in refspecs:
        out.append(spec.split(":", 1)[1] if ":" in spec else spec)
    return out


def check_git_push(args: List[str], cwd: str, config: dict) -> Optional[str]:
    for arg in args:
        if arg in _FORBIDDEN_PUSH_FLAGS:
            return (
                "`{0}` is never permitted in a benchmark run: it either bypasses "
                "the ref allow-list or destroys history.".format(arg)
            )
    allowed = config["allowed_refs"]
    # The reason reaches the model, so it names branches the way a person
    # would rather than echoing anchored regexes at it.
    described = config.get("allowed_refs_human") or allowed
    for ref in push_destinations(args, cwd):
        if not ref_allowed(ref, allowed):
            return (
                "this benchmark cell may only push to: {0}. `{1}` is outside "
                "that and was not pushed.".format(", ".join(described), ref)
            )
    return None


def check_gh(args: List[str], config: dict) -> Optional[str]:
    """Rules for the `gh` CLI.

    Draft is enforced here rather than trusted to the approach because the
    SDLC playbook creates a normal PR and then calls `gh pr ready` on it. Both
    halves are handled: creation must be draft, and undrafting is refused.
    """
    joined = " ".join(args)
    if len(args) >= 3 and args[:3] == ["gh", "pr", "create"]:
        if not any(a in ("--draft", "-d") for a in args):
            return (
                "benchmark pull requests must be drafts so branch protection and "
                "auto-merge cannot land one. Re-run this command with `--draft`."
            )
        return None
    if len(args) >= 3 and args[1] == "pr" and args[2] in ("ready", "merge"):
        return (
            "`gh pr {0}` is blocked for the duration of a benchmark run. The PR "
            "is deliberately left as a draft so its output can be reviewed "
            "without any chance of it landing.".format(args[2])
        )
    if len(args) >= 2 and args[1] == "api" and "merge" in joined:
        return (
            "`gh api` calls touching a merge endpoint are blocked for the "
            "duration of a benchmark run."
        )
    return None


def check_command(command: str, cwd: str, config: dict) -> Optional[str]:
    """Return a deny reason, or None to leave the command to normal permissions.

    Returning None is NOT an approval -- the hook stays silent and the usual
    permission rules still apply. Only denial is this hook's business.
    """
    text = command.strip()
    governed = re.search(
        r"\b(git\s+(push|merge|rebase)|gh\s+(pr|api))\b", text
    )
    if not governed:
        return None

    for token in _UNPARSEABLE:
        if token in text:
            return (
                "this command chains or substitutes shell constructs around a "
                "guarded verb ({0}), which cannot be checked reliably. Run the "
                "guarded command on its own.".format(governed.group(0))
            )

    try:
        args = shlex.split(text)
    except ValueError as exc:
        return "cannot parse this command safely ({0}).".format(exc)
    if not args:
        return None

    if args[0] == "git":
        sub = next((a for a in args[1:] if not a.startswith("-")), "")
        if sub == "push":
            return check_git_push(args, cwd, config)
        if sub in ("merge", "rebase"):
            return (
                "`git {0}` is blocked for the duration of a benchmark run: the "
                "run must not integrate its work anywhere.".format(sub)
            )
        return None

    if args[0] == "gh":
        return check_gh(args, config)
    return None


def evaluate(payload: dict) -> Tuple[bool, str]:
    """(allowed, reason). Any failure to establish safety returns denied."""
    if payload.get("tool_name") != "Bash":
        return True, ""
    command = (payload.get("tool_input") or {}).get("command") or ""
    if not command.strip():
        return True, ""

    # Cheap pre-check so a cell without a config can still run every command
    # that this hook does not govern. Loading the config for `ls` would deny
    # the whole session on a config problem that never mattered.
    if not re.search(r"\b(git\s+(push|merge|rebase)|gh\s+(pr|api))\b", command):
        return True, ""

    cwd = payload.get("cwd") or os.getcwd()
    # GuardError is caught HERE rather than only in main(): evaluate() is the
    # decision function, and a decision function that can raise instead of
    # deciding invites a caller to treat the exception as "no opinion". Every
    # path out of here is an explicit allow or an explicit deny.
    try:
        config = find_config(cwd)
        reason = check_command(command, cwd, config)
    except GuardError as exc:
        return False, str(exc)
    if reason:
        return False, reason
    return True, ""


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        allowed, reason = evaluate(payload)
    except GuardError as exc:
        allowed, reason = False, str(exc)
    except Exception as exc:  # noqa: BLE001 - fail closed, deliberately broad
        # An unexpected shape, a broken git, a permissions error: none of them
        # are evidence that a push is safe. A guard that allows on its own bug
        # is not a guard.
        allowed, reason = False, "benchmark guard failed closed: {0}".format(exc)

    if allowed:
        # Silence, not approval: normal permission rules still decide.
        return 0
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
