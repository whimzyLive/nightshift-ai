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
REVIEW_FIX = "review-fix"


def collect_runs(ticket_dir: Path) -> List[dict]:
    runs = []
    skipped = []
    for run_file in sorted(ticket_dir.glob("*/run.json")):
        try:
            run = json.loads(run_file.read_text())
        except (json.JSONDecodeError, IOError) as e:
            skipped.append({"path": str(run_file), "error": str(e)})
            continue
        try:
            grades_file = run_file.parent / "grades.json"
            run["grades"] = json.loads(grades_file.read_text()) if grades_file.exists() else {}
        except (json.JSONDecodeError, IOError) as e:
            skipped.append({"path": str(grades_file), "error": str(e)})
            continue
        run["_skipped"] = []
        runs.append(run)

    # Attach skipped metadata for rendering
    if skipped:
        if runs:
            runs[0]["_file_skipped"] = skipped
        else:
            runs = [{"_file_skipped": skipped}]

    return runs


def phase_rows(runs: List[dict]) -> List[dict]:
    rows = []
    for run in runs:
        # Skip non-run entries (e.g., file skip metadata)
        if "approach" not in run:
            continue

        phases = run.get("by_phase") or {}
        impl = float(phases.get(IMPL, {}).get("cost_usd", 0.0))
        review = float(phases.get(REVIEW_FIX, {}).get("cost_usd", 0.0))
        ceremony = sum(
            float(data.get("cost_usd", 0.0))
            for name, data in phases.items()
            if name not in (IMPL, REVIEW_FIX)
        )
        grades = run.get("grades") or {}
        acs = grades.get("acs") or {}
        reconciliation = run.get("reconciliation") or {}
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
                "regressions": grades.get("regressions", False),
                "grader_failure_count": grades.get("grader_failure_count", 0),
                "reconciled": bool(reconciliation.get("ok")),
                "reconciliation_note": reconciliation.get("note", ""),
            }
        )
    return rows


def artifact_inventory(runs: List[dict]) -> List[dict]:
    inventory = []
    for run in runs:
        # Skip non-run entries and failed reconciliations
        if "approach" not in run:
            continue
        if not (run.get("reconciliation") or {}).get("ok"):
            continue

        phases = run.get("by_phase") or {}
        for name, data in phases.items():
            if name in (IMPL, REVIEW_FIX):
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
        "| Status | Approach            | impl-only $ | review + fix $ | ceremony $ | total $  | Regressions | ACs met   | findings | wall clock |",
        "| ------ | ------------------- | ----------: | -------------: | ----------: | -------: | ----------- | --------- | -------- | ---------- |",
    ]

    failed_notes = []
    for i, row in enumerate(rows):
        status = "OK" if row["reconciled"] else "FAILED"
        impl_str = "{:.2f}".format(row["impl"]) if row["reconciled"] else "—"
        review_str = "{:.2f}".format(row["review_fix"]) if row["reconciled"] else "—"
        ceremony_str = "{:.2f}".format(row["ceremony"]) if row["reconciled"] else "—"

        regressions_str = "yes" if row["regressions"] else "no"
        acs_str = "{0}/{1}".format(row["acs_met"], row["acs_total"])
        if row["grader_failure_count"] > 0:
            acs_str += " ({0} fail)".format(row["grader_failure_count"])

        lines.append(
            "| {0:<6} | {1:<19} | {2:>10} | {3:>14} | {4:>10} | {5:>7} | {6:<11} | {7:<9} | {8:<8} | {9:>10} |".format(
                status,
                row["approach"],
                impl_str,
                review_str,
                ceremony_str,
                "{:.2f}".format(row["total"]),
                regressions_str,
                acs_str,
                row["findings"],
                "{:.1f}s".format(row["duration_ms"] / 1000.0),
            )
        )

        if not row["reconciled"]:
            failed_notes.append((row["approach"], row["reconciliation_note"]))

    # Skipped files section
    skipped_files = None
    for run in runs:
        if "_file_skipped" in run:
            skipped_files = run["_file_skipped"]
            break

    if skipped_files:
        lines += [
            "",
            "## Skipped cells",
            "",
            "The following benchmark cells could not be processed and are excluded from the report:",
            "",
        ]
        for skipped in skipped_files:
            lines.append("- `{0}`: {1}".format(skipped["path"], skipped["error"]))

    # Footnotes for failed reconciliation
    if failed_notes:
        lines += [
            "",
            "## Failed reconciliations",
            "",
            "The following rows failed reconciliation (reconstructed per-phase cost drifted past 2% tolerance).",
            "Their per-phase figures are omitted from the comparison. **Do not use these rows for cost analysis.**",
            "",
        ]
        for approach, note in failed_notes:
            if note:
                lines.append("- **{0}**: {1}".format(approach, note))
            else:
                lines.append("- **{0}**: per-phase reconstruction drifted past tolerance.".format(approach))

    # Artifact inventory
    inventory = artifact_inventory(runs)
    if inventory:
        lines += [
            "",
            "## Artifact inventory",
            "",
            "What the ceremony spend bought (failed rows excluded).",
            "",
            "| Approach | Phase | Cost $ |",
            "| --- | --- | ---: |",
        ]
        for item in inventory:
            lines.append(
                "| {0:<19} | {1:<12} | {2:>6.2f} |".format(
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
