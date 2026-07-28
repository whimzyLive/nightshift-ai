#!/usr/bin/env python3
"""Turn a session transcript into per-phase cost and token metrics.

claude -p --output-format json reports total_cost_usd and modelUsage[<model>].costUSD,
which are authoritative. Those totals cannot be split across phases, so per-phase figures
are reconstructed from the transcript and then reconciled against the reported total.
A run whose reconstruction drifts past tolerance is flagged, never silently reported.

Usage:
  python3 measure.py --cell cell.json --result result.json \
      --adapter plugins/bench/approaches/opus.yaml --out run.json
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters  # noqa: E402

PRICING_PATH = Path(__file__).resolve().parent / "benchlib" / "pricing.json"
PROJECTS_DIR = Path.home() / ".claude" / "projects"
_SUFFIX = re.compile(r"\[.*\]$")


def load_pricing() -> dict:
    """Load per-model rates, unwrapping the "models" section.

    pricing.json also carries a top-level "_calibration_note" documenting
    provenance; nesting real rates under "models" means that note (or any
    future metadata key) can never be mistaken for a model entry by a
    pricing[canonical] lookup.
    """
    data = json.loads(PRICING_PATH.read_text())
    return data["models"]


def price_entry(usage: dict, model: str, pricing: dict) -> float:
    """Price one assistant turn's usage against a model's rate card.

    Real usage payloads split cache-creation tokens by TTL bucket under a
    "cache_creation" sub-object (ephemeral_1h_input_tokens /
    ephemeral_5m_input_tokens), since 1-hour and 5-minute cache writes are
    priced differently (2x vs 1.25x the input rate). When that sub-object is
    present, price each bucket at its own rate. Older or partial payloads
    that only carry the flat "cache_creation_input_tokens" bucket are priced
    at the 1-hour rate as a conservative fallback -- but only when the split
    data isn't available, so real split data is never discarded in favor of
    the fallback.
    """
    canonical = _SUFFIX.sub("", model or "")
    rates = pricing[canonical]

    cache_creation = usage.get("cache_creation")
    if isinstance(cache_creation, dict):
        cache_cost = (
            cache_creation.get("ephemeral_1h_input_tokens", 0) * rates["cache_write_1h"]
            + cache_creation.get("ephemeral_5m_input_tokens", 0) * rates["cache_write_5m"]
        )
    else:
        cache_cost = usage.get("cache_creation_input_tokens", 0) * rates["cache_write_1h"]

    return (
        usage.get("input_tokens", 0) * rates["input"]
        + usage.get("output_tokens", 0) * rates["output"]
        + cache_cost
        + usage.get("cache_read_input_tokens", 0) * rates["cache_read"]
    ) / 1_000_000


def find_transcript(session_id: str) -> Optional[Path]:
    """Locate the transcript for a session id.

    Path.glob does not guarantee ordering. If more than one project
    directory holds a transcript for the same session id, that is an
    anomaly worth investigating (session ids are effectively unique), not
    something to resolve by silently picking whichever the filesystem
    happened to yield first -- a cost-measurement harness that guesses
    wrong here would report a real number for the wrong session. Raise and
    name every candidate so the caller can investigate, rather than guess.
    """
    matches = sorted(PROJECTS_DIR.glob(f"*/{session_id}.jsonl"))
    if not matches:
        return None
    if len(matches) > 1:
        candidates = ", ".join(str(m) for m in matches)
        raise RuntimeError(
            f"ambiguous transcript for session {session_id}: "
            f"multiple candidates found: {candidates}"
        )
    return matches[0]


def read_entries(transcript: Path) -> List[dict]:
    entries = []
    for line in transcript.read_text().splitlines():
        if not line.strip():
            continue
        raw = json.loads(line)
        message = raw.get("message") or {}
        content = message.get("content")
        if isinstance(content, list):
            text = " ".join(
                part.get("text", "") for part in content if isinstance(part, dict)
            )
        else:
            text = str(content or "")
        entries.append(
            {
                "type": raw.get("type"),
                "text": text,
                "model": message.get("model"),
                "usage": message.get("usage") or {},
                "is_sidechain": bool(raw.get("isSidechain")),
                "timestamp": raw.get("timestamp"),
            }
        )
    return entries


def assign_phases(entries: List[dict], phases: List[dict]) -> List[dict]:
    """Tag each entry with the phase whose marker most recently fired.

    Entries before any marker belong to the first declared phase, so preamble
    work is never dropped from the accounting.

    Markers are deliberately raw regex, not literal strings -- adapters use
    alternation (e.g. "/sdlc:review|/sdlc:review-fix") to match more than one
    trigger phrase per phase, so markers are never re.escape()'d. An adapter
    author can still write an invalid pattern (e.g. an unbalanced paren);
    that must fail loudly, naming the offending phase and pattern, rather
    than crashing the whole measurement run with a bare re.error deep in a
    list comprehension.
    """
    compiled = []
    for p in phases:
        marker = p.get("marker")
        if not marker:
            compiled.append((p["id"], None))
            continue
        try:
            pattern = re.compile(marker)
        except re.error as exc:
            raise ValueError(
                f"phase {p['id']!r} has an invalid marker regex {marker!r}: {exc}"
            ) from exc
        compiled.append((p["id"], pattern))
    current = phases[0]["id"] if phases else "impl"
    out = []
    for entry in entries:
        for phase_id, pattern in compiled:
            if pattern is not None and pattern.search(entry.get("text") or ""):
                current = phase_id
                break
        tagged = dict(entry)
        tagged["phase"] = current
        out.append(tagged)
    return out


def instruction_floor(residents: List[int]) -> int:
    return min(residents) if residents else 0


def reconcile(computed: float, reported: float, tolerance: float = 0.02) -> bool:
    if reported <= 0:
        return False
    return abs(computed - reported) / reported <= tolerance


def count_tool_uses(transcript: Path, tool_names: Iterable[str]) -> Dict[str, int]:
    """Count tool_use blocks in a transcript, keyed by tool name.

    Only the names passed in are counted (and always present in the
    result, even at zero) -- e.g. pass ["Edit", "Write"] to get exactly
    those two counters back, ignoring Bash/Read/other tool_use blocks.
    """
    wanted = set(tool_names)
    counts = {name: 0 for name in wanted}
    for line in transcript.read_text().splitlines():
        if not line.strip():
            continue
        raw = json.loads(line)
        message = raw.get("message") or {}
        content = message.get("content")
        if not isinstance(content, list):
            continue
        for part in content:
            if isinstance(part, dict) and part.get("type") == "tool_use":
                name = part.get("name")
                if name in wanted:
                    counts[name] += 1
    return counts


def git_numstat(worktree: str, base_sha: str) -> Dict[str, int]:
    """Summarise `git diff --numstat base..HEAD` in the given worktree.

    Binary files report "-" for added/removed in numstat output; they are
    counted as a touched file but contribute 0 lines either direction.
    """
    result = subprocess.run(
        ["git", "-C", str(worktree), "diff", "--numstat", f"{base_sha}..HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    files_touched = 0
    lines_added = 0
    lines_removed = 0
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        added, removed = parts[0], parts[1]
        files_touched += 1
        if added != "-":
            lines_added += int(added)
        if removed != "-":
            lines_removed += int(removed)
    return {
        "files_touched": files_touched,
        "lines_added": lines_added,
        "lines_removed": lines_removed,
    }


def compute_work_done(cell: dict, transcript: Path) -> Dict[str, int]:
    """Assemble the run.json work_done block: git diff stats + tool-use counts.

    git side: `git diff --numstat` in cell["worktree"] between
    cell["base_sha"] and HEAD. Transcript side: Edit and Write tool_use
    counts, since those are the two tools that touch files.
    """
    stats = git_numstat(cell["worktree"], cell["base_sha"])
    tool_counts = count_tool_uses(transcript, ["Edit", "Write"])
    return {
        "files_touched": stats["files_touched"],
        "lines_added": stats["lines_added"],
        "lines_removed": stats["lines_removed"],
        "edit_calls": tool_counts["Edit"],
        "write_calls": tool_counts["Write"],
    }


def summarise(entries: List[dict], pricing: dict) -> dict:
    by_phase: Dict[str, dict] = {}
    residents: List[int] = []
    for entry in entries:
        if entry["type"] != "assistant":
            continue
        usage = entry["usage"]
        bucket = by_phase.setdefault(
            entry["phase"],
            {
                "cost_usd": 0.0,
                "requests": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_write_tokens": 0,
                "cache_read_tokens": 0,
                "subagent_requests": 0,
            },
        )
        bucket["cost_usd"] += price_entry(usage, entry["model"], pricing)
        bucket["requests"] += 1
        bucket["input_tokens"] += usage.get("input_tokens", 0)
        bucket["output_tokens"] += usage.get("output_tokens", 0)
        bucket["cache_write_tokens"] += usage.get("cache_creation_input_tokens", 0)
        bucket["cache_read_tokens"] += usage.get("cache_read_input_tokens", 0)
        if entry["is_sidechain"]:
            bucket["subagent_requests"] += 1
        residents.append(
            usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
        )

    floor = instruction_floor(residents)
    mean_resident = sum(residents) / len(residents) if residents else 0
    return {
        "by_phase": by_phase,
        "context": {
            "instruction_floor_tokens": floor,
            "mean_resident_tokens": round(mean_resident),
            "peak_resident_tokens": max(residents) if residents else 0,
            "work_context_tokens": round(max(0.0, mean_resident - floor)),
        },
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--result", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    result = json.loads(Path(args.result).read_text())
    adapter = adapters.load_adapter(Path(args.adapter))
    pricing = load_pricing()

    transcript = find_transcript(result["session_id"])
    if transcript is None:
        raise RuntimeError(f"no transcript found for session {result['session_id']}")

    phases = [{"id": p.id, "marker": p.marker} for p in adapter.phases]
    entries = assign_phases(read_entries(transcript), phases)
    summary = summarise(entries, pricing)
    work_done = compute_work_done(cell, transcript)

    computed = sum(bucket["cost_usd"] for bucket in summary["by_phase"].values())
    reported = float(result.get("total_cost_usd") or 0.0)
    ok = reconcile(computed, reported)

    run = {
        "ticket": cell["ticket"],
        "approach": cell["approach"],
        "run_id": cell["run_id"],
        "session_id": result["session_id"],
        "total": {
            "reported_cost_usd": reported,
            "computed_cost_usd": round(computed, 6),
            "duration_ms": result.get("duration_ms"),
            "setup_seconds": result.get("setup_seconds"),
            "num_turns": result.get("num_turns"),
        },
        "by_phase": summary["by_phase"],
        "context": summary["context"],
        "work_done": work_done,
        "reconciliation": {
            "ok": ok,
            "tolerance": 0.02,
            "note": "" if ok else "computed cost drifted past tolerance; excluded from aggregates",
        },
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(run, indent=2))
    status = "ok" if ok else "RECONCILIATION FAILED"
    print(
        "measured {0}: reported=${1:.4f} computed=${2:.4f} [{3}]".format(
            cell["approach"], reported, computed, status
        )
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
