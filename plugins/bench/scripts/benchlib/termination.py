"""Decide whether a measured session terminated cleanly.

Why this exists
---------------
On a subscription, a story-sized session can be cut off mid-run by a rate
limit. The result is a truncated transcript that STILL reports a cost and
STILL reconciles -- reconstructed and reported are both derived from the same
truncated data, so they agree with each other perfectly. Without this check
the harness records a completed cell with suspiciously low spend and a
half-finished diff, and the report renders it `OK`. That is exactly the class
of confidently-wrong number this harness exists to prevent.

Why it is an allow-list
-----------------------
There is NO rate-limit sample available on this machine to pattern-match
against. Across 120 real transcripts inspected here, `stop_reason` only ever
took the values `tool_use` and `end_turn`, and the only `system`/`api_error`
entries found were connection errors whose `rateLimits` field was null.
String-matching against limit messages we have never seen would be guessing,
and would silently pass any wording we guessed wrong.

So the rule is inverted: a cell counts as cleanly terminated ONLY when the
result payload matches the known-good shape, established by direct inspection
of real `claude -p --output-format json` output on this machine:

    is_error: false, subtype: "success", stop_reason: "end_turn",
    terminal_reason: "completed", api_error_status: None

Anything else fails, including values nobody has ever sampled.

Absent versus unexpected
------------------------
An ABSENT optional field is "not observed", not "unexpected value". An older
CLI that never emitted `stop_reason` must not fail every cell. `subtype` is
the exception: it is always present in a real result payload, so its absence
means the payload is not the shape this check was built to verify.

Pacing
------
The founder's ruling: fail loudly, no auto-resume, no sleeping and retrying.
A rate-limited cell is marked FAILED with its reason and the operator re-runs
it later. There is deliberately no waiting logic anywhere in this module.
"""
import json
from pathlib import Path
from typing import Dict, List

CLEAN_SUBTYPE = "success"
CLEAN_STOP_REASON = "end_turn"
CLEAN_TERMINAL_REASON = "completed"

# Recorded verbatim on every cell, clean or not. A reader investigating a
# failed row needs the values that produced the verdict, not a summary of
# them.
OBSERVED_FIELDS = [
    "is_error",
    "subtype",
    "stop_reason",
    "terminal_reason",
    "api_error_status",
    "num_turns",
]


def check_result_payload(payload: dict) -> Dict[str, object]:
    """Allow-list check of the `claude -p --output-format json` result payload.

    Returns {"clean": bool, "observed": {...}, "violations": [str]}.
    """
    observed = {field: payload.get(field) for field in OBSERVED_FIELDS}
    violations: List[str] = []

    if payload.get("is_error"):
        violations.append(
            "is_error is {0!r}, expected false".format(payload.get("is_error"))
        )

    # Always present in a real result payload; absence is itself a violation.
    subtype = payload.get("subtype")
    if subtype != CLEAN_SUBTYPE:
        violations.append(
            "subtype is {0!r}, expected {1!r}".format(subtype, CLEAN_SUBTYPE)
        )

    # Optional fields: only an OBSERVED unexpected value is a violation.
    stop_reason = payload.get("stop_reason")
    if stop_reason is not None and stop_reason != CLEAN_STOP_REASON:
        violations.append(
            "stop_reason is {0!r}, expected {1!r} (a result payload that stopped "
            "for any other reason did not finish its work)".format(
                stop_reason, CLEAN_STOP_REASON
            )
        )

    terminal_reason = payload.get("terminal_reason")
    if terminal_reason is not None and terminal_reason != CLEAN_TERMINAL_REASON:
        violations.append(
            "terminal_reason is {0!r}, expected {1!r}".format(
                terminal_reason, CLEAN_TERMINAL_REASON
            )
        )

    api_error_status = payload.get("api_error_status")
    if api_error_status is not None:
        violations.append(
            "api_error_status is {0!r}, expected null".format(api_error_status)
        )

    # A session that took no turns did no work, whatever else the payload says.
    #
    # Observed on NA-82: an adapter prompt of `/sdlc:auto NA-83` came back as
    # subtype "success", is_error false, num_turns 0, duration 11ms,
    # total_cost_usd 0, and result "Unknown command: /sdlc:auto". Every
    # allow-listed field above was clean, so the cell was recorded as a
    # successful $0 run and only the downstream empty-diff check noticed
    # anything was wrong -- which reads as "the approach produced no code",
    # not "the prompt never reached a model".
    #
    # Those are different failures and must not look alike: the first is a
    # result about an approach, the second is a broken cell.
    num_turns = payload.get("num_turns")
    if isinstance(num_turns, int) and num_turns <= 0:
        violations.append(
            "num_turns is {0!r} -- the session took no turns, so nothing was "
            "measured. The prompt was rejected or the session died before its "
            "first turn; the result text says why.".format(num_turns)
        )

    # The CLI reports an unrecognised slash command as a successful result whose
    # text is the error. Checked explicitly because it is the single most likely
    # way an adapter prompt silently measures nothing.
    result_text = payload.get("result")
    if isinstance(result_text, str) and result_text.strip().startswith(
        "Unknown command:"
    ):
        violations.append(
            "the session rejected the prompt: {0!r}. An adapter prompt cannot "
            "invoke a plugin command with slash syntax in a headless session; "
            "ask for the capability in plain language instead.".format(
                result_text.strip()[:120]
            )
        )

    return {"clean": not violations, "observed": observed, "violations": violations}


def scan_transcript(transcript) -> List[dict]:
    """Find `system`/`api_error` transcript entries that carry rate-limit data.

    The `error` object has a dedicated `rateLimits` field which exists
    specifically to carry rate-limit information. In the real samples on this
    machine it was null (those were connection errors), so a null value is
    explicitly NOT a violation -- only a populated one is.

    A malformed line never aborts the scan: this runs after a session that has
    already been paid for, and losing the record to a JSON error in one line
    would be the worst possible failure mode.
    """
    found: List[dict] = []
    try:
        text = Path(transcript).read_text()
    except (IOError, OSError):
        return found

    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            raw = json.loads(line)
        except ValueError:
            continue
        if not isinstance(raw, dict):
            continue
        if raw.get("type") != "system" or raw.get("subtype") != "api_error":
            continue
        error = raw.get("error")
        if not isinstance(error, dict):
            continue
        rate_limits = error.get("rateLimits")
        if rate_limits is None:
            continue
        found.append(
            {
                "timestamp": raw.get("timestamp"),
                "status": error.get("status"),
                "formatted": error.get("formatted"),
                "retryAttempt": raw.get("retryAttempt"),
                "rateLimits": rate_limits,
            }
        )
    return found


def combine(result_check: dict, rate_limit_entries: List[dict]) -> Dict[str, object]:
    """Merge the result-payload verdict with the transcript scan.

    Either source alone is sufficient to fail the cell: the result payload can
    look perfectly normal while the transcript shows the session was throttled
    partway through.
    """
    violations = list(result_check.get("violations") or [])
    for entry in rate_limit_entries:
        violations.append(
            "transcript carries a system/api_error entry with a populated "
            "rateLimits field: {0}".format(
                json.dumps(entry.get("rateLimits"), sort_keys=True, default=str)
            )
        )

    clean = not violations
    if clean:
        note = ""
    else:
        note = (
            "FAILED CELL: the measured session did not terminate cleanly, so its "
            "cost and diff describe a partial run, not a completed one. A "
            "truncated session still reports a cost and still reconciles, which "
            "is why this is checked separately. Observed: {0}. No auto-resume is "
            "attempted by design -- re-run this cell by hand once the cause has "
            "cleared.".format("; ".join(violations))
        )

    return {
        "clean": clean,
        "observed": result_check.get("observed") or {},
        "violations": violations,
        "rate_limit_entries": rate_limit_entries,
        "note": note,
    }
