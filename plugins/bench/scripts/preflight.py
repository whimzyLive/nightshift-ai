#!/usr/bin/env python3
"""State a sweep's cost and blast radius before its first cell runs.

`execute.py` already guards one cell: it refuses to start if the run would be
billed to an API key. This guards the SWEEP, and the two are different
questions. A single cell is cheap enough not to matter; eight cold cells, each
re-reading a system prompt, plugin definitions and CLAUDE.md at full rate, draw
down a subscription limit that announces itself only by running out.

It also counts what a sweep will CREATE, not just what it will cost. Approaches
that write to Jira get a cloned issue, a branch and a draft pull request per
cell, so an accidentally-wide sweep is a cleanup problem measured in hours as
well as a quota problem. Both numbers are stated up front rather than
discovered.

Nothing here spends anything or writes anything outside stdout.

Usage:
  python3 preflight.py --ticket NA-68 --repo . \
      --adapter approaches/opus.yaml --adapter approaches/sdlc-0.45.4.yaml \
      --repeats 2 [--acknowledge-cost] [--max-cells 24]
"""
import argparse
import sys
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

import report  # noqa: E402
from benchlib import acli, adapters, quota  # noqa: E402


def collect_history(repo: Path, ticket: str) -> List[dict]:
    """Prior runs for this ticket, or [] if there are none.

    A forecast built from this ticket's own measured cost beats the module
    default, which is an invented number. Failures here are non-fatal: a
    missing or unreadable benchmark directory means no history, not an error --
    the first sweep on a ticket has none by definition.
    """
    ticket_dir = Path(repo) / "docs" / "benchmarks" / ticket
    if not ticket_dir.is_dir():
        return []
    try:
        return [run for run in report.collect_runs(ticket_dir) if "approach" in run]
    except (IOError, OSError, ValueError):
        return []


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticket", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument(
        "--adapter",
        action="append",
        required=True,
        help="Approach YAML. Repeat once per approach in the sweep.",
    )
    parser.add_argument(
        "--repeats",
        type=int,
        default=1,
        help=(
            "Runs per approach. More than one is what gives a delta a noise "
            "floor -- a single run per cell cannot tell a real difference from "
            "sampling spread."
        ),
    )
    parser.add_argument(
        "--acknowledge-cost",
        action="store_true",
        help=(
            "Proceed with a sweep whose forecast exceeds the cost threshold. "
            "Does NOT clear the cell cap: acknowledging a cell count you did "
            "not intend to produce is not consent."
        ),
    )
    parser.add_argument("--max-cells", type=int, default=quota.DEFAULT_MAX_CELLS)
    parser.add_argument(
        "--threshold-usd", type=float, default=quota.DEFAULT_CONFIRM_THRESHOLD_USD
    )
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    loaded = [adapters.load_adapter(Path(p)) for p in args.adapter]
    cells = len(loaded) * max(args.repeats, 0)

    history = collect_history(repo, args.ticket)
    measured = quota.measured_per_cell_usd(history)
    per_cell = measured if measured is not None else quota.DEFAULT_PER_CELL_USD

    print("Sweep preflight for {0}".format(args.ticket))
    print(
        "  {0} approach(es) x {1} repeat(s) = {2} cold session(s)".format(
            len(loaded), args.repeats, cells
        )
    )
    for adapter in loaded:
        print(
            "    {0} — plugins: {1}".format(
                adapter.cell_id, ", ".join(adapter.plugins) or "none"
            )
        )
    print(
        "  cost basis: {0}".format(
            "measured from {0} prior run(s) on this ticket (${1:.2f}/cell)".format(
                len(history), per_cell
            )
            if measured is not None
            else "no prior runs on this ticket; using the ${0:.2f}/cell "
            "default, which is an order of magnitude and not a quote".format(per_cell)
        )
    )

    # Blast radius, stated separately from cost because it is not undone by
    # having budget for it.
    writers = [a for a in loaded if a.dedicated_ticket]
    if writers:
        needed = len(writers) * max(args.repeats, 0)
        print(
            "  NEEDS {0} pre-made twin ticket(s), one per cell, from: {1}".format(
                needed, ", ".join(a.cell_id for a in writers)
            )
        )
        print(
            "    Each twin must have story points set and carry the `{0}` label. "
            "The harness cannot create them -- acli on this build cannot write "
            "story points by any route, and an unpointed ticket triages down the "
            "wrong path while the row claims the full lifecycle.".format(
                acli.BENCH_LABEL
            )
        )
        print(
            "  WILL CREATE: {0} branch(es) and up to {0} draft pull request(s). "
            "Clear them afterwards with /bench:cleanup {1} -- which keeps the "
            "twins and deletes only their branches.".format(needed, args.ticket)
        )
    else:
        print(
            "  WILL CREATE: no Jira issues or pull requests (no approach writes Jira)"
        )

    try:
        forecast = quota.preflight(
            cells,
            acknowledged=args.acknowledge_cost,
            per_cell_usd=per_cell,
            threshold_usd=args.threshold_usd,
            max_cells=args.max_cells,
        )
    except quota.QuotaGuardError as exc:
        print("")
        print("ABORTED: {0}".format(exc))
        # Distinct from 1 so a caller can tell a refusal from a crash.
        return 2

    print(
        "  estimated: ~${0:.2f} API-equivalent total{1}".format(
            forecast["estimated_usd"],
            " (cost threshold acknowledged)" if args.acknowledge_cost else "",
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
