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
        attribution = run.get("phase_attribution") or {}
        work_done = run.get("work_done") or {}
        term = run.get("termination") or {}

        # A run.json written before phase_attribution existed has no opinion;
        # treat that as available rather than retroactively invalidating it.
        attribution_available = attribution.get("available", True)

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
                "attribution_available": attribution_available,
                "attribution_note": attribution.get("note", ""),
                "empty_diff": bool(work_done.get("empty_diff")),
                "empty_diff_note": work_done.get("empty_diff_note", ""),
                # A run.json written before the termination check existed has
                # no opinion; treat that as clean rather than retroactively
                # marking every historical row as cut off.
                "termination_clean": bool(term.get("clean", True)),
                "termination_note": term.get("note", ""),
                "termination_observed": term.get("observed") or {},
                "termination_violations": term.get("violations") or [],
                "rate_limit_entries": term.get("rate_limit_entries") or [],
                # grade.py refused to grade: the raw diff was non-empty but
                # every changed path was stripped as a process artifact.
                "filtered_diff_empty": bool(grades.get("filtered_diff_empty")),
                "filtered_diff_note": grades.get("filtered_diff_note", ""),
                "stripped_paths": grades.get("stripped_paths") or [],
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
        # A row whose markers never fired has no real ceremony bucket -- its
        # spend was dumped into the first declared phase. Listing that as
        # "what the ceremony spend bought" would launder the same fabricated
        # number the main table refuses to print.
        if not (run.get("phase_attribution") or {}).get("available", True):
            continue
        # A cut-off cell's per-phase figures are the cost of a partial run.
        # Listing them as "what the ceremony spend bought" would present a
        # truncated session's spend as a completed deliverable.
        if not (run.get("termination") or {}).get("clean", True):
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


def billing_modes(runs: List[dict]) -> List[tuple]:
    """The (mode, evidence) pairs observed across these runs, deduplicated.

    Read from each run's record rather than assumed. A sweep's rows can
    legitimately disagree — one cell measured before a key was exported and
    one after — and a report that picked either as "the" mode would be
    asserting something it does not know.
    """
    seen: List[tuple] = []
    for run in runs:
        if "approach" not in run:
            continue
        recorded = run.get("billing_mode") or {}
        mode = recorded.get("mode") or "unknown"
        evidence = recorded.get("evidence") or ""
        if not evidence:
            evidence = (
                "no billing mode was recorded for this run, so whether its figures "
                "are real API spend or subscription API-equivalents cannot be "
                "determined from the record."
            )
        pair = (mode, evidence)
        if pair not in seen:
            seen.append(pair)
    return seen


# Why the money columns are labelled API-eq rather than plainly "$":
# `total_cost_usd` is what the tokens WOULD cost at API list price. When
# `claude` authenticates against an operator's subscription rather than an
# API key, no per-run charge is incurred, so a column headed "total $" is
# read as money that left an account when none did. The cross-approach
# comparison is unaffected either way — every approach is priced identically
# — so only the labelling was wrong.
COST_BASIS_NOTE = [
    "Dollar columns are **API-equivalents**: what the tokens consumed would cost at",
    "API list price. They are not a bill. On a subscription run **no per-run charge is",
    "incurred** — no money leaves an account. The comparison across approaches still",
    "holds regardless, because every approach is priced against the same rate card.",
]


def render_markdown(ticket: str, runs: List[dict]) -> str:
    rows = phase_rows(runs)
    lines = [
        f"# Benchmark: {ticket}",
        "",
        "Cost is split by phase. `impl-only` is the comparable figure across approaches;",
        "`review + fix` and `ceremony` are what the process-heavy approaches additionally buy.",
        "",
        "| Status   | Approach            | impl-only API-eq $ | review + fix API-eq $ | ceremony API-eq $ | total API-eq $ | Regressions | ACs met   | findings | wall clock |",
        "| -------- | ------------------- | -----------------: | --------------------: | ----------------: | -------------: | ----------- | --------- | -------- | ---------- |",
    ]

    failed_notes = []
    unattributed_notes = []
    empty_diff_notes = []
    cut_off_notes = []
    no_patch_notes = []
    for i, row in enumerate(rows):
        # Four independent reasons a row's numbers cannot be shown as-is.
        # Order matters only for the status label; the em dashes are the
        # same either way, because in every one of these cases the split is
        # not a measurement.
        #
        # CUT OFF is checked FIRST and deliberately: a session that did not
        # terminate cleanly explains every other symptom it produces (a
        # half-finished diff, a broken phase split, a suspiciously low cost),
        # so labelling it by one of those symptoms would bury the cause.
        if not row["termination_clean"]:
            status = "CUT OFF"
        elif row["empty_diff"]:
            status = "NO DIFF"
        elif row["filtered_diff_empty"]:
            status = "NO PATCH"
        elif not row["reconciled"]:
            status = "FAILED"
        elif not row["attribution_available"]:
            status = "NO SPLIT"
        else:
            status = "OK"

        show_split = (
            row["reconciled"]
            and row["attribution_available"]
            and not row["empty_diff"]
            and row["termination_clean"]
        )
        impl_str = "{:.2f}".format(row["impl"]) if show_split else "—"
        review_str = "{:.2f}".format(row["review_fix"]) if show_split else "—"
        ceremony_str = "{:.2f}".format(row["ceremony"]) if show_split else "—"

        # The total is normally still a valid figure even when the split is
        # not. A cut-off cell is the one case where it is not: it is the cost
        # of a partial run, and printing it invites reading a truncated
        # session as a cheap one.
        total_str = "—" if not row["termination_clean"] else "{:.2f}".format(row["total"])

        regressions_str = "yes" if row["regressions"] else "no"
        # The COST columns stay valid for a NO PATCH row -- the session ran
        # and its spend was measured; what is missing is anything gradable.
        # Only the quality columns are meaningless.
        if row["empty_diff"] or not row["termination_clean"] or row["filtered_diff_empty"]:
            # 0 findings against an empty or partial diff is not a clean
            # result; it is a grader with nothing to grade. Never render it
            # as 0.
            acs_str = "—"
            findings_str = "—"
        else:
            acs_str = "{0}/{1}".format(row["acs_met"], row["acs_total"])
            if row["grader_failure_count"] > 0:
                acs_str += " ({0} fail)".format(row["grader_failure_count"])
            findings_str = str(row["findings"])

        lines.append(
            "| {0:<8} | {1:<19} | {2:>18} | {3:>21} | {4:>17} | {5:>14} | {6:<11} | {7:<9} | {8:<8} | {9:>10} |".format(
                status,
                row["approach"],
                impl_str,
                review_str,
                ceremony_str,
                total_str,
                regressions_str,
                acs_str,
                findings_str,
                "{:.1f}s".format(row["duration_ms"] / 1000.0),
            )
        )

        if not row["termination_clean"]:
            cut_off_notes.append(row)
        if row["filtered_diff_empty"]:
            no_patch_notes.append(row)
        if not row["reconciled"]:
            failed_notes.append((row["approach"], row["reconciliation_note"]))
        if not row["attribution_available"]:
            unattributed_notes.append((row["approach"], row["attribution_note"]))
        if row["empty_diff"]:
            empty_diff_notes.append((row["approach"], row["empty_diff_note"]))

    # Cost basis, stated directly under the table. Read from what each run
    # recorded at execute time -- never hardcoded to either mode.
    modes = billing_modes(runs)
    lines.append("")
    if len(modes) == 1:
        lines.append("Billing mode: **{0}**. {1}".format(modes[0][0], modes[0][1]))
    elif len(modes) > 1:
        lines.append(
            "Billing mode: **{0}** (rows in this sweep were not all measured on the "
            "same basis).".format(", ".join(mode for mode, _ in modes))
        )
        lines.append("")
        for mode, evidence in modes:
            lines.append("- **{0}**: {1}".format(mode, evidence))
    lines.append("")
    lines += COST_BASIS_NOTE

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

    # Footnotes for abnormally terminated cells
    if cut_off_notes:
        lines += [
            "",
            "## Abnormal termination — cells cut off mid-run",
            "",
            "These cells' sessions did **not** terminate cleanly, so every figure they",
            "produced describes a partial run. **They are failed cells, not cheap ones.**",
            "A truncated session still reports a cost and still reconciles — reconstructed",
            "and reported are both derived from the same truncated data — which is why this",
            "is checked separately and why the whole row, total included, is shown as `—`.",
            "",
            "The check is an allow-list: a cell passes only when its result payload matches",
            "the known-good shape (`is_error: false`, `subtype: \"success\"`,",
            "`stop_reason: \"end_turn\"`, `terminal_reason: \"completed\"`, no",
            "`api_error_status`) and its transcript carries no `system`/`api_error` entry",
            "with a populated `rateLimits` field. Observed values are recorded verbatim.",
            "",
            "**No auto-resume is attempted.** Re-run the cell by hand once the cause has",
            "cleared — on a subscription the usual cause is exhausting the rate-limit window.",
            "",
        ]
        for row in cut_off_notes:
            lines.append("- **{0}**".format(row["approach"]))
            for violation in row["termination_violations"]:
                lines.append("  - {0}".format(violation))
            if row["termination_observed"]:
                lines.append(
                    "  - observed: `{0}`".format(
                        json.dumps(row["termination_observed"], sort_keys=True, default=str)
                    )
                )
            for entry in row["rate_limit_entries"]:
                lines.append(
                    "  - rate-limit entry: `{0}`".format(
                        json.dumps(entry, sort_keys=True, default=str)
                    )
                )
            if not row["termination_violations"] and row["termination_note"]:
                lines.append("  - {0}".format(row["termination_note"]))

    # Footnotes for cells with nothing gradable left after filtering
    if no_patch_notes:
        lines += [
            "",
            "## Nothing gradable — the filtered patch was empty",
            "",
            "These cells produced a **non-empty** diff, but every changed path was stripped",
            "as a process artifact (`.claude/`, `.superpowers/`, `docs/adr/`, plan documents,",
            "...) before grading, leaving the graders an empty patch. Grading that yields 0",
            "findings and unmet ACs against nothing, which reads as a clean result and is",
            "not one — so these cells were **not graded** and their quality columns show `—`.",
            "",
            "Their **cost columns remain valid**: the session ran and its spend was measured.",
            "What is missing is any code change to judge. The usual cause is a cell whose",
            "whole deliverable legitimately lives under a stripped path — in which case this",
            "ticket is not a suitable benchmark subject for the blinding rules in force.",
            "",
        ]
        for row in no_patch_notes:
            note = row["filtered_diff_note"] or (
                "the raw diff was non-empty but filtered down to nothing."
            )
            lines.append("- **{0}**: {1}".format(row["approach"], note))

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

    # Footnotes for unavailable phase attribution
    if unattributed_notes:
        lines += [
            "",
            "## Phase attribution unavailable",
            "",
            "These rows declared more than one phase, but **no phase marker matched anywhere in",
            "the transcript** — so every entry defaulted into whichever phase was declared first",
            "and the whole run's spend landed in one bucket. That is an artefact of the",
            "attribution rule, not a measurement, so the impl-only / review + fix / ceremony",
            "split is shown as `—`. **The total $ column is still valid** — only the split is not.",
            "",
            "This is what happens when an approach's phases run inline inside one session rather",
            "than being triggered by literal slash commands the marker regex can see.",
            "",
        ]
        for approach, note in unattributed_notes:
            if note:
                lines.append("- **{0}**: {1}".format(approach, note))
            else:
                lines.append(
                    "- **{0}**: multiple phases declared, no marker ever fired.".format(approach)
                )

    # Footnotes for cells that produced no code change
    if empty_diff_notes:
        lines += [
            "",
            "## Failed cells — no code change",
            "",
            "These cells ran a measured session and produced an **empty diff** against their base",
            "commit. There is nothing to grade, so ACs and findings are shown as `—` rather than",
            "as a clean `0/0` with 0 findings. **These are failed cells, not good results.**",
            "The usual cause is the session being unable to commit (missing Bash permission), or",
            "the model finishing without writing anything.",
            "",
        ]
        for approach, note in empty_diff_notes:
            if note:
                lines.append("- **{0}**: {1}".format(approach, note))
            else:
                lines.append("- **{0}**: `git diff base_sha..HEAD` was empty.".format(approach))

    # Artifact inventory
    inventory = artifact_inventory(runs)
    if inventory:
        lines += [
            "",
            "## Artifact inventory",
            "",
            "What the ceremony spend bought, in API-equivalent dollars (failed rows excluded).",
            "",
            "| Approach | Phase | Cost (API-eq $) |",
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
