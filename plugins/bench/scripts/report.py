#!/usr/bin/env python3
"""Render the aggregate comparison report.

Cost is never presented as a single number. impl-only is the apples-to-apples
figure; review+fix is what QA discipline costs; ceremony is spec/plan/docs.
Splitting them is what keeps the comparison fair to an approach that reviews its
own work against approaches that do not.

Usage:
  python3 report.py --ticket NA-80 --benchmarks docs/benchmarks --out docs/benchmarks/NA-80/report.md
"""
import argparse
import json
from pathlib import Path
from typing import List, Optional

IMPL = "impl"
REVIEW = "review-fix"


def collect_runs(ticket_dir: Path) -> List[dict]:
    runs = []
    for run_file in sorted(ticket_dir.glob("*/run.json")):
        run = json.loads(run_file.read_text())
        grades_file = run_file.parent / "grades.json"
        run["grades"] = json.loads(grades_file.read_text()) if grades_file.exists() else {}
        runs.append(run)
    return runs


def phase_rows(runs: List[dict]) -> List[dict]:
    rows = []
    for run in runs:
        phases = run.get("by_phase") or {}
        impl = float(phases.get(IMPL, {}).get("cost_usd", 0.0))
        review = float(phases.get(REVIEW, {}).get("cost_usd", 0.0))
        ceremony = sum(
            float(data.get("cost_usd", 0.0))
            for name, data in phases.items()
            if name not in (IMPL, REVIEW)
        )
        grades = run.get("grades") or {}
        acs = grades.get("acs") or {}
        rows.append(
            {
                "approach": run["approach"],
                "impl": impl,
                "review_fix": review,
                "ceremony": ceremony,
                "total": float(run["total"].get("reported_cost_usd", 0.0)),
                "duration_ms": run["total"].get("duration_ms") or 0,
                "acs_met": sum(1 for ac in acs.values() if ac.get("met")),
                "acs_total": len(acs),
                "findings": grades.get("findings_count", 0),
                "reconciled": bool((run.get("reconciliation") or {}).get("ok")),
            }
        )
    return rows


def artifact_inventory(runs: List[dict]) -> List[dict]:
    inventory = []
    for run in runs:
        phases = run.get("by_phase") or {}
        for name, data in phases.items():
            if name in (IMPL, REVIEW):
                continue
            inventory.append(
                {
                    "approach": run["approach"],
                    "phase": name,
                    "cost_usd": float(data.get("cost_usd", 0.0)),
                }
            )
    return inventory


def render_markdown(ticket: str, runs: List[dict]) -> str:
    rows = phase_rows(runs)
    lines = [
        f"# Benchmark: {ticket}",
        "",
        "Cost is split by phase. `impl-only` is the comparable figure across approaches;",
        "`review + fix` and `ceremony` are what the process-heavy approaches additionally buy.",
        "",
        "| Approach | impl-only $ | review + fix $ | ceremony $ | total $ | ACs met | findings | wall clock |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        flag = "" if row["reconciled"] else " **RECONCILIATION FAILED**"
        lines.append(
            "| {0}{1} | {2:.2f} | {3:.2f} | {4:.2f} | {5:.2f} | {6}/{7} | {8} | {9:.1f}s |".format(
                row["approach"],
                flag,
                row["impl"],
                row["review_fix"],
                row["ceremony"],
                row["total"],
                row["acs_met"],
                row["acs_total"],
                row["findings"],
                row["duration_ms"] / 1000.0,
            )
        )

    inventory = artifact_inventory(runs)
    if inventory:
        lines += [
            "",
            "## Artifact inventory",
            "",
            "What the ceremony spend bought.",
            "",
            "| Approach | Phase | Cost $ |",
            "| --- | --- | ---: |",
        ]
        for item in inventory:
            lines.append(
                "| {0} | {1} | {2:.2f} |".format(
                    item["approach"], item["phase"], item["cost_usd"]
                )
            )

    return "\n".join(lines) + "\n"


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticket", required=True)
    parser.add_argument("--benchmarks", default="docs/benchmarks")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    ticket_dir = Path(args.benchmarks) / args.ticket
    runs = collect_runs(ticket_dir)
    if not runs:
        raise RuntimeError(f"no runs found under {ticket_dir}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_markdown(args.ticket, runs))
    print(f"wrote {out} ({len(runs)} runs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
