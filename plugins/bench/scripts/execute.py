#!/usr/bin/env python3
"""Execute one benchmark cell.

setup hooks run OUTSIDE the measured window. Installing a toolchain is a one-time
tax paid per machine, not a per-story cost, so charging it to the first story
would misrepresent the approach.

Usage:
  python3 execute.py --cell cell.json --story story.json \
      --adapter plugins/bench/approaches/opus.yaml --out result.json
"""
import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters, config, plugins, termination  # noqa: E402

# Environment variables that put `claude` on a pay-per-token API key rather
# than the operator's subscription. Checked for PRESENCE only -- the value is
# a credential and is never read into any recorded structure.
API_KEY_ENV_VARS = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"]

# Claude Code's "simple"/bare mode. Under it, auth is strictly
# ANTHROPIC_API_KEY or apiKeyHelper -- OAuth and the keychain are never read
# (confirmed via `claude --help`: --bare "Sets CLAUDE_CODE_SIMPLE=1 ... OAuth
# and keychain are never read"). So a run under this mode cannot be billed to
# the operator's subscription no matter what settings say.
SIMPLE_MODE_ENV_VAR = "CLAUDE_CODE_SIMPLE"
SIMPLE_MODE_FLAG = "--bare"


class BillingGuardError(RuntimeError):
    """Raised by the preflight guard when a run would consume money or quota
    on a basis the operator did not deliberately choose. Never constructed
    with a credential value -- only variable/setting NAMES.
    """


def settings_candidates(repo: Path) -> List[Path]:
    """Settings files whose contents can put a run on an API key.

    Order is the order Claude Code itself resolves them, most general first.
    """
    return [
        Path.home() / ".claude" / "settings.json",
        Path(repo) / ".claude" / "settings.json",
        Path(repo) / ".claude" / "settings.local.json",
    ]


def detect_billing_mode(
    env: Dict[str, str], settings_paths: List[Path]
) -> Dict[str, object]:
    """Decide whether this run is billed to an API key or to a subscription.

    Why this is recorded PER RUN and not stated once in a doc: a sweep can be
    run on a different machine, or on this one after someone exports a key.
    `total_cost_usd` means two genuinely different things in those two cases
    -- real spend against an account, versus an API-list-price equivalent for
    tokens that incurred no per-run charge. A reader months later has no way
    to reconstruct which basis a row sat on unless the row says so itself.

    Only PRESENCE and the variable NAME are recorded. The credential value is
    never read into the returned structure, and therefore never reaches
    result.json or run.json.
    """
    api_key_env_var = None
    for name in API_KEY_ENV_VARS:
        # An exported-but-empty variable is not a key. Treating it as one
        # would mislabel a subscription run as API-billed.
        if (env.get(name) or "").strip():
            api_key_env_var = name
            break

    settings_evidence: List[str] = []
    settings_checked: List[str] = []
    for path in settings_paths:
        settings_checked.append(str(path))
        try:
            data = json.loads(Path(path).read_text())
        except (IOError, OSError, ValueError):
            # A missing or malformed settings file is not evidence of a key.
            # It must never abort a run that has yet to spend anything.
            continue
        if not isinstance(data, dict):
            continue
        if (data.get("apiKeyHelper") or "") != "":
            settings_evidence.append("{0}: apiKeyHelper is set".format(path))
        env_block = data.get("env")
        if isinstance(env_block, dict):
            for name in API_KEY_ENV_VARS:
                if (env_block.get(name) or "") != "":
                    settings_evidence.append(
                        "{0}: env.{1} is set".format(path, name)
                    )

    is_api = api_key_env_var is not None or bool(settings_evidence)
    if is_api:
        reasons = []
        if api_key_env_var:
            reasons.append("{0} is set in the environment".format(api_key_env_var))
        reasons.extend(settings_evidence)
        evidence = (
            "API key in play ({0}) -- cost figures are real spend against that "
            "key.".format("; ".join(reasons))
        )
    else:
        evidence = (
            "no API key present (checked {0} and {1} settings file(s)) -- "
            "`claude` authenticates via the operator's Claude subscription, so "
            "reported cost figures are API-list-price equivalents for the tokens "
            "consumed, not per-run spend.".format(
                ", ".join(API_KEY_ENV_VARS), len(settings_checked)
            )
        )

    return {
        "mode": "api" if is_api else "subscription",
        "api_key_env_var": api_key_env_var,
        "settings_evidence": settings_evidence,
        "env_vars_checked": list(API_KEY_ENV_VARS),
        "settings_files_checked": settings_checked,
        "evidence": evidence,
    }


def detect_simple_mode(env: Dict[str, str], flags: List[str]) -> Optional[str]:
    """Is this run's `claude` invocation going to run under simple/bare mode?

    Under simple mode, OAuth and the keychain are never read -- auth is
    strictly ANTHROPIC_API_KEY or apiKeyHelper. So a run that would enter
    simple mode cannot land on the operator's subscription regardless of
    what `detect_billing_mode` finds, and must be treated as an abort
    condition of its own.

    Only presence and the triggering name are returned -- never a value.
    """
    if (env.get(SIMPLE_MODE_ENV_VAR) or "").strip():
        return "{0} is set in the environment".format(SIMPLE_MODE_ENV_VAR)
    if SIMPLE_MODE_FLAG in flags:
        return "the adapter passes {0} (sets {1}=1)".format(
            SIMPLE_MODE_FLAG, SIMPLE_MODE_ENV_VAR
        )
    return None


def billing_preflight(
    env: Dict[str, str],
    settings_paths: List[Path],
    flags: List[str],
    allow_api_billing: bool,
) -> Dict[str, object]:
    """Abort BEFORE any money-or-quota-consuming work if this run would be
    billed to an API key or would run under simple mode.

    This is deliberately separate from -- but built on -- detect_billing_mode:
    recording the basis after the session has already run is not enough. A
    key exported in some future shell, or a settings change, could route a
    whole sweep to API billing and only be noticed once someone reads
    run.json. This makes that outcome loud and immediate, before the first
    setup hook or `claude` subprocess, so nothing has been spent yet.

    Returns the billing-mode record that gated this decision, so the caller
    records the SAME evaluation rather than recomputing one later that could
    disagree with what actually gated the run (e.g. a key unset mid-run).

    `allow_api_billing` is the one explicit, per-invocation escape hatch
    (the CLI's --allow-api-billing). There is deliberately no environment
    variable equivalent -- an env var escape hatch would be defeated by
    exactly the scenario this guard exists to catch.
    """
    mode = detect_billing_mode(env, settings_paths)
    simple_reason = detect_simple_mode(env, flags)

    if simple_reason and mode["mode"] != "api":
        # Simple mode forces API-only auth even when no key evidence was
        # found elsewhere. Reporting "subscription" here would misstate what
        # actually happens -- the subscription credential is never read.
        mode = dict(mode)
        mode["mode"] = "api"
        mode["evidence"] = (
            "simple mode is active ({0}) -- OAuth and the keychain are never "
            "read under it, so this run cannot be billed to the operator's "
            "subscription regardless of other key evidence.".format(simple_reason)
        )

    if allow_api_billing:
        return mode

    reasons: List[str] = []
    if simple_reason:
        reasons.append(simple_reason)
    if mode["mode"] == "api" and not simple_reason:
        reasons.append(mode["evidence"].rstrip("."))
    if not reasons:
        return mode

    raise BillingGuardError(
        "refusing to start: this run would NOT be billed to the operator's "
        "Claude subscription -- {0}. Nothing has been spent -- this check "
        "runs before any setup hook or `claude` invocation. If an "
        "API-billed comparison run is genuinely wanted, re-run with "
        "--allow-api-billing.".format("; ".join(reasons))
    )


def assert_cell_matches_adapter(cell: dict, adapter) -> None:
    """The cell's identity and the adapter's must be the same thing.

    provision.py builds paths and the branch from `--approach`/`--version`;
    the adapter declares its own id and pin. If those drift -- a cell
    provisioned as `sdlc@0.44.0` executed with the 0.45.4 adapter -- every
    artifact would be filed under a version it did not measure, which is
    precisely the mislabelling this feature exists to prevent. Cheap to
    check, and it costs nothing to fail here.
    """
    expected = adapter.cell_id
    actual = cell.get("approach")
    if actual != expected:
        raise plugins.PluginPinError(
            "cell/adapter mismatch: this cell was provisioned as {0!r} but the "
            "adapter resolves to {1!r}. Re-provision with --approach {2} "
            "{3}or pass the matching adapter.".format(
                actual,
                expected,
                adapter.id,
                "--version {0} ".format(adapter.version.version) if adapter.version else "",
            )
        )

    declared = cell.get("version")
    pinned = adapter.version.version if adapter.version else None
    if (declared or None) != (pinned or None):
        raise plugins.PluginPinError(
            "cell/adapter version mismatch: cell says {0!r}, adapter says "
            "{1!r}.".format(declared, pinned)
        )


def build_variables(
    cell: dict, story: dict, test_command: str, base_branch: str = ""
) -> Dict[str, str]:
    return {
        # The scratch issue when the approach writes to Jira, the source
        # ticket otherwise. Only the SESSION follows the scratch key: paths,
        # branch, artifacts and the report row stay keyed on the source, so
        # every cell of one story still groups together.
        "ticket_key": cell.get("scratch_ticket") or story["key"],
        "ticket_summary": story["summary"],
        "ticket_description": story["description"],
        "ticket_acs": story["acs"],
        "worktree": cell["worktree"],
        "artifacts": cell["artifacts"],
        "base_branch": base_branch,
        "test_command": test_command,
    }


def claude_argv(flags: List[str], model: str) -> List[str]:
    """The prompt is fed on stdin, never as an argv element — a long ticket
    description would otherwise risk the command-line length limit.

    `--model` is always passed, from the adapter's required `run.model`.
    Leaving it off means the row measures the operator's default model
    rather than the one its label names.
    """
    return [
        "claude",
        "--print",
        "--output-format",
        "json",
        "--model",
        model,
    ] + list(flags)


def render_hook(template: str, variables: Dict[str, str]) -> str:
    """Render a hook command string with shell-escaped variable substitution.

    Unlike prompt rendering (which is never shell-evaluated), hook commands
    are executed with shell=True. All substituted values must be shell-quoted
    to prevent command injection from ticket text (summary, description, acs)
    that may contain semicolons, backticks, $(...), newlines, etc.
    """
    result = template
    for key, value in variables.items():
        placeholder = "{{" + key + "}}"
        if placeholder in result:
            # Shell-quote the value to escape any metacharacters
            quoted_value = shlex.quote(value)
            result = result.replace(placeholder, quoted_value)
    return result


def run_hooks(commands: List[str], cwd: Path, variables: Dict[str, str]) -> None:
    for command in commands:
        rendered = render_hook(command, variables)
        proc = subprocess.run(rendered, shell=True, cwd=str(cwd))
        if proc.returncode != 0:
            raise RuntimeError(f"hook failed ({proc.returncode}): {rendered}")


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--story", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--allow-api-billing",
        action="store_true",
        help=(
            "Explicit, per-invocation escape hatch. Without it, the preflight "
            "guard aborts any run that would be billed to an API key or would "
            "run under simple mode. There is no environment-variable "
            "equivalent by design."
        ),
    )
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    story = json.loads(Path(args.story).read_text())
    adapter = adapters.load_adapter(Path(args.adapter))

    # Preflight guard: abort BEFORE any money-or-quota-consuming work (setup
    # hooks, the `claude` subprocess) if this run would be API-billed or
    # would run under simple mode. See billing_preflight for why this can't
    # wait until after the session runs. billing_mode is recorded verbatim
    # into result.json below -- reusing this exact evaluation rather than
    # recomputing one later.
    billing_mode = billing_preflight(
        dict(os.environ),
        settings_candidates(Path(cell["repo"])),
        adapter.flags,
        args.allow_api_billing,
    )

    # Identity check before anything is spent: a cell filed under one version
    # but executed with another adapter would mislabel every artifact.
    assert_cell_matches_adapter(cell, adapter)

    cfg = config.load_config(Path(cell["repo"]), {})

    worktree = Path(cell["worktree"])

    # Version pin preflight. The cache garbage-collects unreferenced versions,
    # so the target may simply be gone; failing here costs nothing, whereas
    # discovering it after the session means a row labelled with a version
    # that was never loaded.
    pin_record = None
    plugins_snapshot = None
    pin_applied = False
    if adapter.version is not None:
        plugins.assert_version_available(adapter.version.plugin, adapter.version.version)
        plugins_snapshot = plugins.read_snapshot()
        # To DISK, before the pin. The in-memory snapshot below covers an
        # exception and a clean exit; it cannot survive the process being
        # killed, and a cell is a long job an operator will interrupt. When
        # that happened it left the operator's main repo without its plugin
        # registrations. provision.py sweeps this marker on the next run.
        plugins.write_durable_snapshot(plugins_snapshot)

    # Everything below runs under `finally: restore`. The pin mutates a file
    # this harness does not own (~/.claude/plugins/installed_plugins.json),
    # shared with every other Claude Code session on this machine, so leaving
    # it rewritten is not an acceptable failure mode for ANY exit path --
    # including an exception, a cut-off session, or a teardown error. This is
    # deliberately not an adapter `teardown:` hook: teardown failures here are
    # reported rather than fatal, which is the wrong tier for un-breaking the
    # operator's plugin installation.
    try:
        if adapter.version is not None:
            pin_record = plugins.apply_pin(
                adapter.version.plugin,
                adapter.version.version,
                str(worktree),
            )
            pin_applied = True
            print(
                "pinned {0} to {1} for {2}".format(
                    adapter.version.plugin, adapter.version.version, worktree
                )
            )

        # Validate BEFORE the session runs. cfg.test_command is what the adapter
        # prompt tells the model to run and what /bench:run captures as the
        # grader's test evidence. If it is missing or unusable, fail here -- a
        # cell that discovers it post-session has already spent the money and can
        # only hand graders a shell error to grade.
        test_command = config.require_command(
            cfg.test_command, "test", source=str(Path(cell["repo"]) / config.CONTEXT_PATH)
        )
        variables = build_variables(cell, story, test_command, cfg.base_branch)

        setup_started = time.time()
        run_hooks(adapter.setup, worktree, variables)
        setup_seconds = time.time() - setup_started

        prompt = adapters.render(adapter.prompt, variables)
        # Archived for the record: the exact prompt is part of the run's evidence.
        Path(cell["artifacts"]).joinpath("prompt.txt").write_text(prompt)

        started_at = datetime.now(timezone.utc).isoformat()
        proc = subprocess.run(
            claude_argv(adapter.flags, adapter.model),
            cwd=str(worktree),
            input=prompt,
            capture_output=True,
            text=True,
        )
        ended_at = datetime.now(timezone.utc).isoformat()

        if proc.returncode != 0:
            Path(cell["artifacts"]).joinpath("claude.stderr").write_text(proc.stderr)
            raise RuntimeError(f"claude exited {proc.returncode}; stderr archived in artifacts")

        # Archive raw stdout BEFORE attempting to parse. If JSON parsing fails,
        # the raw output is preserved for diagnostics.
        artifacts_dir = Path(cell["artifacts"])
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        artifacts_dir.joinpath("claude.stdout.raw").write_text(proc.stdout)

        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError as e:
            raise RuntimeError(
                f"claude stdout is not valid JSON; raw output archived in artifacts/claude.stdout.raw: {e}"
            )

        payload["started_at"] = started_at
        payload["ended_at"] = ended_at
        payload["setup_seconds"] = round(setup_seconds, 3)
        # Which basis this cell's dollar figures sit on. This is the SAME
        # evaluation the preflight guard used to decide whether to let the run
        # start, not a fresh recomputation -- so a --allow-api-billing run is
        # recorded as `api` even if, say, a key were unset in between (it can't
        # misrepresent what actually gated this run). See billing_preflight.
        payload["billing_mode"] = billing_mode
        # What this cell CLAIMS it measured. measure.py independently recovers
        # what the session actually loaded from the transcript and compares the
        # two -- this field alone is an intent, not evidence.
        # What the session ran inside: the exact plugin set enabled, everything
        # explicitly disabled, and any hook from user/project settings that
        # could not be turned off. Written by provision.py at worktree-creation
        # time and carried verbatim, so the record reflects what actually
        # gated this cell rather than a re-derivation from a machine whose
        # settings may have changed since.
        payload["environment"] = cell.get("environment")
        payload["plugin_version"] = {
            "declared": (
                {
                    "plugin": adapter.version.plugin,
                    "version": adapter.version.version,
                }
                if adapter.version is not None
                else None
            ),
            "pin": pin_record,
        }
        # Allow-list check of the result payload's termination shape. Recorded
        # here so an abnormal end is visible immediately rather than only after
        # measure runs; measure re-derives it from the same fields and adds the
        # transcript scan. See benchlib/termination.py.
        payload["termination"] = termination.check_result_payload(payload)

        # Write result.json BEFORE running teardown. If teardown fails, the
        # already-paid-for result is still captured on disk.
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2))

        # Run teardown. Failures are reported but do not destroy the captured result.
        teardown_error = None
        try:
            run_hooks(adapter.teardown, worktree, variables)
        except RuntimeError as e:
            teardown_error = e

        print(
            "executed {0} (model={1}): session={2} cost=${3:.4f} API-equiv "
            "[billing mode: {4}]".format(
                adapter.cell_id,
                adapter.model,
                payload.get("session_id"),
                payload.get("total_cost_usd", 0.0),
                payload["billing_mode"]["mode"],
            )
        )

        # Loud, and never silently swallowed. The result is still on disk: this
        # cell's record is evidence, and measure.py needs it to render the row as
        # failed. No auto-resume is attempted -- see benchlib/termination.py.
        if not payload["termination"]["clean"]:
            print(
                "ABNORMAL TERMINATION -- this cell is FAILED, not measured: {0}".format(
                    "; ".join(payload["termination"]["violations"])
                )
            )

        if teardown_error is not None:
            raise RuntimeError(
                f"result captured successfully to {args.out}, but teardown failed: {teardown_error}"
            )

        return 0
    finally:
        if pin_applied:
            plugins.restore_snapshot(plugins_snapshot)
            # Only now: while the marker exists, the next provision treats this
            # run as abandoned and restores from it.
            plugins.clear_durable_snapshot()
            print("restored installed_plugins.json to its pre-run state")


if __name__ == "__main__":
    raise SystemExit(main())
