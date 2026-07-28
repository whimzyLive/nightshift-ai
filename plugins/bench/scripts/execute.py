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
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters, config  # noqa: E402


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
        "executed {0} (model={1}): session={2} cost=${3:.4f}".format(
            adapter.id,
            adapter.model,
            payload.get("session_id"),
            payload.get("total_cost_usd", 0.0),
        )
    )

    if teardown_error is not None:
        raise RuntimeError(
            f"result captured successfully to {args.out}, but teardown failed: {teardown_error}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
