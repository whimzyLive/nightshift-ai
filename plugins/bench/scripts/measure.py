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
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters  # noqa: E402

PRICING_PATH = Path(__file__).resolve().parent / "benchlib" / "pricing.json"
PROJECTS_DIR = Path.home() / ".claude" / "projects"
_SUFFIX = re.compile(r"\[.*\]$")


def load_pricing() -> dict:
    return json.loads(PRICING_PATH.read_text())


def price_entry(usage: dict, model: str, pricing: dict) -> float:
    canonical = _SUFFIX.sub("", model or "")
    rates = pricing[canonical]
    return (
        usage.get("input_tokens", 0) * rates["input"]
        + usage.get("output_tokens", 0) * rates["output"]
        + usage.get("cache_creation_input_tokens", 0) * rates["cache_write"]
        + usage.get("cache_read_input_tokens", 0) * rates["cache_read"]
    ) / 1_000_000


def find_transcript(session_id: str) -> Optional[Path]:
    matches = list(PROJECTS_DIR.glob(f"*/{session_id}.jsonl"))
    return matches[0] if matches else None


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
    """
    compiled = [(p["id"], re.compile(p["marker"]) if p.get("marker") else None) for p in phases]
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
