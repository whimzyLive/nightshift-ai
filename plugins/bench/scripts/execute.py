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


def claude_argv(flags: List[str]) -> List[str]:
    """The prompt is fed on stdin, never as an argv element — a long ticket
    description would otherwise risk the command-line length limit."""
    return [
        "claude",
        "--print",
        "--output-format",
        "json",
    ] + list(flags)


def run_hooks(commands: List[str], cwd: Path, variables: Dict[str, str]) -> None:
    for command in commands:
        rendered = adapters.render(command, variables)
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
    variables = build_variables(cell, story, cfg.test_command, cfg.base_branch)

    setup_started = time.time()
    run_hooks(adapter.setup, worktree, variables)
    setup_seconds = time.time() - setup_started

    prompt = adapters.render(adapter.prompt, variables)
    # Archived for the record: the exact prompt is part of the run's evidence.
    Path(cell["artifacts"]).joinpath("prompt.txt").write_text(prompt)

    started_at = datetime.now(timezone.utc).isoformat()
    proc = subprocess.run(
        claude_argv(adapter.flags),
        cwd=str(worktree),
        input=prompt,
        capture_output=True,
        text=True,
    )
    ended_at = datetime.now(timezone.utc).isoformat()

    if proc.returncode != 0:
        Path(cell["artifacts"]).joinpath("claude.stderr").write_text(proc.stderr)
        raise RuntimeError(f"claude exited {proc.returncode}; stderr archived in artifacts")

    payload = json.loads(proc.stdout)
    payload["started_at"] = started_at
    payload["ended_at"] = ended_at
    payload["setup_seconds"] = round(setup_seconds, 3)

    run_hooks(adapter.teardown, worktree, variables)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2))
    print(
        "executed {0}: session={1} cost=${2:.4f}".format(
            adapter.id, payload.get("session_id"), payload.get("total_cost_usd", 0.0)
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
