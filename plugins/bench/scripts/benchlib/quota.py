"""Quota preflight for a benchmark sweep.

Each cell is a COLD `claude -p` session, and that is deliberate: cells sharing
a warm cache in one live session would make whichever approach ran second look
cheaper purely from cache reuse, so the comparison would measure run order
rather than approach. The cold start is part of what an approach genuinely
costs.

The price of that correctness is quota. A cold session pays full rate for its
system prompt, plugin definitions and skills on every cell, where a
continuation would read them from cache at a fraction. A four-approach sweep
with two repeats is eight of those, and on a subscription that draws down a
limit no error message announces in advance.

So a sweep states its cost before it starts rather than discovering it. The
estimate is deliberately coarse -- it is a decision aid, not an accounting
system, and it says so in its own output.
"""
from typing import Dict, List, Optional

# Observed on this workspace: a cold session with a plugin enabled carries a
# system prompt, plugin command/skill definitions and CLAUDE.md before it does
# any work. Used only for the fixed floor per cell; the variable cost of the
# work itself is what `per_cell_usd` covers.
DEFAULT_COLD_START_TOKENS = 25_000

# A full SDLC lifecycle on a small story, measured in API-equivalent dollars.
# Deliberately a single blunt number rather than a per-approach table: the
# harness has no measured history yet, and a table of invented per-approach
# figures would look like data.
DEFAULT_PER_CELL_USD = 3.0

# Above this, a sweep does not start without an explicit acknowledgement.
DEFAULT_CONFIRM_THRESHOLD_USD = 25.0

# Hard ceiling on cells in one sweep. Not a cost control -- a blast-radius
# control. Each SDLC cell creates a Jira issue, a branch and a draft PR, and a
# typo in a loop that produces sixty of those is a cleanup problem measured in
# hours.
DEFAULT_MAX_CELLS = 24


class QuotaGuardError(RuntimeError):
    """Raised before anything is spent. Never raised mid-sweep."""


def estimate(
    cells: int,
    per_cell_usd: float = DEFAULT_PER_CELL_USD,
    cold_start_tokens: int = DEFAULT_COLD_START_TOKENS,
) -> Dict[str, object]:
    """A coarse forecast for a sweep of `cells` cold sessions."""
    total = round(cells * per_cell_usd, 2)
    return {
        "cells": cells,
        "per_cell_usd": per_cell_usd,
        "estimated_usd": total,
        "cold_start_tokens_per_cell": cold_start_tokens,
        "estimated_cold_start_tokens": cells * cold_start_tokens,
        "basis": (
            "coarse: {0} cold sessions at ~${1:.2f} API-equivalent each, plus "
            "~{2:,} tokens per cell of system prompt, plugin definitions and "
            "CLAUDE.md that a cold session cannot read from cache. Replace "
            "per_cell_usd with a measured figure once this ticket has real "
            "run.json data -- until then this is an order of magnitude, not a "
            "quote.".format(cells, per_cell_usd, cold_start_tokens)
        ),
    }


def preflight(
    cells: int,
    acknowledged: bool = False,
    per_cell_usd: float = DEFAULT_PER_CELL_USD,
    threshold_usd: float = DEFAULT_CONFIRM_THRESHOLD_USD,
    max_cells: int = DEFAULT_MAX_CELLS,
) -> Dict[str, object]:
    """Abort before the first cell if a sweep is larger than intended.

    Two independent gates, because they fail differently. The cell cap catches
    a mistake -- a loop that expanded wrong -- and no acknowledgement clears
    it, since acknowledging a number you did not intend to produce is not
    consent. The cost threshold catches an intentional but expensive sweep,
    and that one an operator can wave through.
    """
    if cells <= 0:
        raise QuotaGuardError(
            "a sweep of {0} cells has nothing to run.".format(cells)
        )
    if cells > max_cells:
        raise QuotaGuardError(
            "refusing to start: {0} cells exceeds the {1}-cell ceiling. Each "
            "cell is a cold session and, for approaches that write to Jira, a "
            "new issue, branch and draft pull request -- so an accidental "
            "sweep is a cleanup problem as much as a cost one. Split the "
            "sweep, or raise --max-cells deliberately.".format(cells, max_cells)
        )

    forecast = estimate(cells, per_cell_usd)
    if forecast["estimated_usd"] > threshold_usd and not acknowledged:
        raise QuotaGuardError(
            "refusing to start: this sweep is estimated at ~${0:.2f} "
            "API-equivalent across {1} cold sessions, over the ${2:.2f} "
            "threshold. On a subscription this draws down quota rather than "
            "billing an account, so nothing will warn you mid-sweep. Nothing "
            "has been spent -- this runs before the first cell. Re-run with "
            "--acknowledge-cost to proceed.\n{3}".format(
                forecast["estimated_usd"], cells, threshold_usd, forecast["basis"]
            )
        )

    forecast["acknowledged"] = acknowledged
    forecast["threshold_usd"] = threshold_usd
    return forecast


def measured_per_cell_usd(runs: List[dict]) -> Optional[float]:
    """Mean reported cost across runs that actually carry one.

    Lets a second sweep on a ticket estimate from that ticket's own history
    instead of the invented default. Returns None when there is nothing to
    learn from, so the caller keeps the default rather than dividing by zero
    and reporting $0.00 as a forecast.
    """
    costs = []
    for run in runs:
        value = ((run or {}).get("total") or {}).get("reported_cost_usd")
        if isinstance(value, (int, float)) and value > 0:
            costs.append(float(value))
    if not costs:
        return None
    return round(sum(costs) / len(costs), 4)
