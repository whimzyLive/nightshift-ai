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
from benchlib import adapters, config, termination  # noqa: E402

# Environment variables that put `claude` on a pay-per-token API key rather
# than the operator's subscription. Checked for PRESENCE only -- the value is
# a credential and is never read into any recorded structure.
API_KEY_ENV_VARS = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"]


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


def build_variables(
    cell: dict, story: dict, test_command: str, base_branch: str = ""
) -> Dict[str, str]:
    return {
        "ticket_key": story["key"],
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
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    story = json.loads(Path(args.story).read_text())
    adapter = adapters.load_adapter(Path(args.adapter))
    cfg = config.load_config(Path(cell["repo"]), {})

    worktree = Path(cell["worktree"])

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
    # Which basis this cell's dollar figures sit on. Recorded per run, never
    # inferred later -- see detect_billing_mode.
    payload["billing_mode"] = detect_billing_mode(
        dict(os.environ), settings_candidates(Path(cell["repo"]))
    )
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
            adapter.id,
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


if __name__ == "__main__":
    raise SystemExit(main())
