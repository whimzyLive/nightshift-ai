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
from collections import namedtuple
from pathlib import Path
from typing import Dict, Iterable, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters, termination  # noqa: E402

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


class UnpriceableModelError(KeyError):
    """No rate card exists for this model id.

    Subclasses KeyError because that is what an unguarded pricing[model]
    lookup used to raise -- but it is caught and recorded, never allowed to
    abort a measurement. A run that has already been paid for must always
    produce a run.json; losing the spend to a bare traceback because one
    turn used an unrecognised model is the worst possible failure mode for
    a cost-measurement harness.
    """


def canonical_model(model: str) -> str:
    """Strip the context-window suffix (e.g. "claude-opus-5[1m]")."""
    return _SUFFIX.sub("", model or "")


def usage_token_total(usage: dict) -> int:
    """Total billable tokens in a usage payload, across every class."""
    cache_creation = usage.get("cache_creation")
    if isinstance(cache_creation, dict):
        cache_written = cache_creation.get(
            "ephemeral_1h_input_tokens", 0
        ) + cache_creation.get("ephemeral_5m_input_tokens", 0)
    else:
        cache_written = usage.get("cache_creation_input_tokens", 0)
    return (
        usage.get("input_tokens", 0)
        + usage.get("output_tokens", 0)
        + cache_written
        + usage.get("cache_read_input_tokens", 0)
    )


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
    canonical = canonical_model(model)
    try:
        rates = pricing[canonical]
    except KeyError:
        raise UnpriceableModelError(canonical)

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


def price_or_record(
    usage: dict, model: str, pricing: dict, unpriceable: Dict[str, int]
) -> float:
    """Price a turn, RECORDING rather than raising on an unknown model id.

    A turn whose usage is entirely zero costs nothing under any rate card,
    so an unknown model with no tokens is not recorded -- there is no
    information to lose, and flagging it would fail reconciliation over an
    accounting non-event (Claude Code's `<synthetic>` pseudo-model, used for
    locally generated error text, is always all-zero). Anything else is
    recorded by model id and contributes 0.0 to the total: the honest floor,
    since inventing a rate would be worse than admitting we do not have one.
    """
    try:
        return price_entry(usage, model, pricing)
    except UnpriceableModelError:
        if usage_token_total(usage) > 0:
            name = canonical_model(model) or "<missing model id>"
            unpriceable[name] = unpriceable.get(name, 0) + 1
        return 0.0


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
    """Parse a transcript into per-entry accounting records.

    Two independent sources of spend live in one transcript:

      1. The MAIN session's own turns -- `type == "assistant"` entries, priced
         from `message.usage` against `message.model`.
      2. SUBAGENT turns -- which do NOT appear in this file as entries at all.
         A subagent runs in its own transcript; the parent session records
         only the rolled-up `toolUseResult.usage`, `toolUseResult.resolvedModel`
         and `toolUseResult.agentId` on the entry that carries the tool result.

    Reading `isSidechain` was the earlier attempt at (2) and finds nothing:
    across 60 recent real transcripts on this machine there are ZERO
    `isSidechain: true` entries, so subagent spend was silently absent from
    every per-phase figure while still being inside the reported total --
    small enough (measured: 1.8% of one real session) to pass the 2%
    reconciliation tolerance and look clean.

    `is_sidechain` is still parsed: it costs nothing and remains the correct
    marker if a future harness version does inline subagent turns.
    """
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

        tool_text = tool_use_text(content)

        tool_result = raw.get("toolUseResult")
        if not isinstance(tool_result, dict):
            tool_result = {}
        subagent_usage = tool_result.get("usage")
        if not isinstance(subagent_usage, dict):
            subagent_usage = None

        entries.append(
            {
                "type": raw.get("type"),
                "text": text,
                "tool_text": tool_text,
                "model": message.get("model"),
                "usage": message.get("usage") or {},
                "is_sidechain": bool(raw.get("isSidechain")),
                "subagent_usage": subagent_usage,
                "subagent_model": tool_result.get("resolvedModel"),
                "subagent_id": tool_result.get("agentId"),
                "timestamp": raw.get("timestamp"),
            }
        )
    return entries


# Tool-call fields a phase marker can meaningfully key on. Deliberately a
# short allow-list rather than the whole input dict: a Write or Edit input
# carries the entire file body, and matching markers across megabytes of file
# content per entry is both slow and a source of accidental fires (a marker
# like "qa-engineer" would match any file that merely mentions it).
_MARKER_TOOL_FIELDS = (
    "subagent_type",
    "skill",
    "command",
    "description",
    "file_path",
    "notebook_path",
    "pattern",
    "path",
    "url",
)

# Enough to carry an agent name, a skill name or a command line; far short of
# a file body.
_MARKER_FIELD_LIMIT = 500


def tool_use_text(content) -> str:
    """The searchable trace of what an entry DID, for phase markers.

    `text` above holds only `text` content parts, so a turn whose entire
    substance is a tool call -- dispatching the `solutions-architect` agent,
    invoking a skill, running a command -- contributes an empty string and is
    invisible to markers. That matters because every framework worth
    benchmarking runs its phases inline through tool calls rather than by
    typing slash commands, so keying phases off prose alone means keying them
    off narration the model is free not to write.

    Kept separate from `text` so token accounting and any future consumer of
    the model's actual words are unaffected by what is matched here.
    """
    if not isinstance(content, list):
        return ""
    parts: List[str] = []
    for part in content:
        if not isinstance(part, dict) or part.get("type") != "tool_use":
            continue
        parts.append(str(part.get("name") or ""))
        data = part.get("input")
        if not isinstance(data, dict):
            continue
        for field in _MARKER_TOOL_FIELDS:
            value = data.get(field)
            if isinstance(value, str) and value:
                parts.append(value[:_MARKER_FIELD_LIMIT])
    return " ".join(parts)


PhaseAssignment = namedtuple("PhaseAssignment", "entries marker_fires")


def assign_phases_with_fires(
    entries: List[dict], phases: List[dict]
) -> PhaseAssignment:
    """Tag each entry with the phase whose marker most recently fired, and
    report how many times each phase's marker actually matched.

    The fire counts are not diagnostics -- they are the only evidence that
    the per-phase split means anything. `current` seeds to the first declared
    phase and moves only on a marker match, so an approach whose phases run
    inline inside a single `claude -p` session (every approach that is not
    literally typing slash commands) fires no marker at all and lands 100% of
    its spend in whichever phase happens to be declared first. That produced
    a real report row reading `| OK | sdlc | 0.00 | 0.00 | 27.07 | 27.07 |`
    whose impl-only figure -- the report's central claim -- was fabricated
    and unflagged. Callers must consult these counts before presenting a
    split.

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
    fires: Dict[str, int] = {}
    for p in phases:
        fires[p["id"]] = 0
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
            haystack = "{0} {1}".format(entry.get("text") or "", entry.get("tool_text") or "")
            if pattern is not None and pattern.search(haystack):
                current = phase_id
                fires[phase_id] += 1
                break
        tagged = dict(entry)
        tagged["phase"] = current
        out.append(tagged)
    return PhaseAssignment(entries=out, marker_fires=fires)


def assign_phases(entries: List[dict], phases: List[dict]) -> List[dict]:
    """Tagged entries only. See assign_phases_with_fires for the fire counts."""
    return assign_phases_with_fires(entries, phases).entries


def phase_attribution(phases: List[dict], marker_fires: Dict[str, int]) -> dict:
    """Decide whether this run's per-phase split is meaningful, and say why.

    Two cases look identical in the data and must not be conflated:

      * ONE declared phase with an empty marker (opus.yaml) -- there is
        nothing to attribute, every entry belongs to the only phase there is,
        and the split is trivially correct. `available: true`.
      * SEVERAL declared phases and no marker ever fired -- everything landed
        in the first declared phase by default, which is an artefact of the
        seeding rule, not a measurement. `available: false`.
    """
    declared = [p["id"] for p in phases]
    total_fires = sum(marker_fires.values())
    available = len(declared) <= 1 or total_fires > 0
    if available:
        note = ""
    else:
        note = (
            "phase attribution unavailable: {0} phases declared ({1}) but no phase "
            "marker matched anywhere in the transcript, so every entry defaulted to "
            "the first declared phase. The per-phase split for this row is an "
            "artefact, not a measurement.".format(len(declared), ", ".join(declared))
        )
    return {
        "declared_phases": declared,
        "markers_declared": sum(1 for p in phases if p.get("marker")),
        "marker_fires": dict(marker_fires),
        "any_marker_fired": total_fires > 0,
        "available": available,
        "note": note,
    }


def billing_mode_from_result(result: dict) -> dict:
    """Carry execute.py's billing-mode record through into run.json.

    A result.json written before that field existed is reported as "unknown",
    never defaulted to either basis: silently labelling an old row
    "subscription" would be exactly the kind of confidently-wrong claim this
    harness exists to avoid.
    """
    recorded = result.get("billing_mode")
    if isinstance(recorded, dict) and recorded.get("mode"):
        return recorded
    return {
        "mode": "unknown",
        "api_key_env_var": None,
        "settings_evidence": [],
        "evidence": (
            "this result.json carries no billing_mode record (written before the "
            "field existed), so whether its cost figures are real API spend or "
            "subscription API-equivalents cannot be determined from the record."
        ),
    }


# Plugins announce their resolved root into session context via a SessionStart
# hook, in the shape:
#   "SDLC plugin root (this session): /Users/x/.claude/plugins/cache/nightshift/sdlc/0.45.4"
# The line is emitted by a script living INSIDE the resolved directory, so its
# presence is evidence that that directory is what executed -- not merely what
# some config file claimed. Path characters stop at whitespace, a quote, or a
# backslash because the transcript is JSON-escaped JSONL.
_PLUGIN_ROOT = re.compile(
    r"([A-Za-z][\w .-]*?) plugin root \(this session\): ([^\s\"\\]+)"
)


def resolved_plugin_versions(transcript) -> Dict[str, dict]:
    """Recover which plugin versions the session ACTUALLY loaded.

    The adapter's declared pin is an intent. This is the independent check on
    it: if the pin silently failed to apply, the declared and resolved
    versions disagree and the row can be marked rather than published under a
    version it did not measure.

    Keyed by the installed-plugin key (`sdlc@nightshift`) so it can be
    compared directly against an adapter's `version.plugin`.
    """
    if transcript is None:
        return {}
    try:
        text = Path(transcript).read_text(errors="ignore")
    except (IOError, OSError):
        return {}

    found: Dict[str, dict] = {}
    for _label, raw_path in _PLUGIN_ROOT.findall(text):
        path = Path(raw_path)
        version = path.name
        plugin = path.parent.name
        marketplace = path.parent.parent.name
        if not version or not plugin or not marketplace:
            continue
        found["{0}@{1}".format(plugin, marketplace)] = {
            "version": version,
            "install_path": raw_path,
        }
    return found


def plugin_version_verdict(result: dict, transcript) -> dict:
    """Compare the cell's declared version pin against what actually ran.

    Three outcomes, deliberately distinct:

    - no pin declared: nothing to verify. Any versions recovered from the
      transcript are still recorded, because knowing what ran is useful even
      when nothing was pinned.
    - declared and resolved agree: verified.
    - declared and resolved disagree: `ok` is false. This is a mislabelled
      row, which is worse than a missing one -- a benchmark that reports
      0.44.0's cost under 0.45.4's name silently inverts the conclusion the
      operator is trying to reach.

    A pin that cannot be verified (the plugin announces no root line) is NOT
    treated as a failure -- absence of the hook is not evidence of the wrong
    version -- but it is reported so the reader knows the label rests on the
    declaration alone.
    """
    declared = (result.get("plugin_version") or {}).get("declared")
    resolved = resolved_plugin_versions(transcript)

    if not declared:
        return {
            "declared": None,
            "resolved": resolved,
            "verified": False,
            "ok": True,
            "note": "no version pin declared for this cell; nothing to verify.",
        }

    key = declared.get("plugin")
    want = declared.get("version")
    actual = resolved.get(key)

    if actual is None:
        return {
            "declared": declared,
            "resolved": resolved,
            "verified": False,
            "ok": True,
            "note": (
                "{0} was pinned to {1}, but the session transcript carries no "
                "plugin-root announcement for it, so the version rests on the "
                "declaration alone and could not be independently "
                "confirmed.".format(key, want)
            ),
        }

    if actual["version"] != want:
        return {
            "declared": declared,
            "resolved": resolved,
            "verified": True,
            "ok": False,
            "note": (
                "VERSION MISMATCH: {0} was pinned to {1} but the session actually "
                "loaded {2} (from {3}). Every figure in this row describes {2}, not "
                "{1}.".format(key, want, actual["version"], actual["install_path"])
            ),
        }

    return {
        "declared": declared,
        "resolved": resolved,
        "verified": True,
        "ok": True,
        "note": "{0} {1} confirmed from the session transcript.".format(key, want),
    }


def termination_verdict(result: dict, transcript) -> dict:
    """Whether this cell's session terminated cleanly, from both evidence sources.

    Re-derived here from the result payload rather than trusting the verdict
    execute.py stored alongside it, so a result.json written before that field
    existed is still checked, and so the two can never silently diverge.
    """
    return termination.combine(
        termination.check_result_payload(result),
        termination.scan_transcript(transcript),
    )


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

    # An empty diff is a FAILED CELL, not a zero result. Everything
    # downstream reads as success: the graders receive an empty patch and
    # honestly report 0 findings and no regressions, and the report renders
    # a clean row. Nothing else in the pipeline can tell the difference
    # between "produced no defects" and "produced no code", so it has to be
    # detected here and said loudly.
    empty_diff = stats["files_touched"] == 0
    note = ""
    if empty_diff:
        note = (
            "no code change: `git diff {0}..HEAD` in {1} is empty. The measured "
            "session ran but committed nothing, so there is nothing to grade. "
            "The session made {2} Edit and {3} Write tool call(s) -- if those are "
            "non-zero the work was done but never committed (check that the "
            "worktree's .claude/settings.local.json grants Bash(git commit:*)); "
            "if they are zero the session produced no work at all.".format(
                cell["base_sha"],
                cell["worktree"],
                tool_counts["Edit"],
                tool_counts["Write"],
            )
        )

    return {
        "files_touched": stats["files_touched"],
        "lines_added": stats["lines_added"],
        "lines_removed": stats["lines_removed"],
        "edit_calls": tool_counts["Edit"],
        "write_calls": tool_counts["Write"],
        "empty_diff": empty_diff,
        "empty_diff_note": note,
    }


def _new_bucket() -> dict:
    return {
        "cost_usd": 0.0,
        "requests": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_write_tokens": 0,
        "cache_read_tokens": 0,
        "subagent_requests": 0,
        "subagent_cost_usd": 0.0,
        "subagent_tokens": 0,
    }


def summarise(entries: List[dict], pricing: dict) -> dict:
    """Roll entries up into per-phase cost, tokens and context metrics.

    `cost_usd` per phase is main-session cost PLUS subagent cost attributed
    to that phase, because that is what the phase actually cost. The
    subagent share is also broken out separately (`subagent_cost_usd` /
    `subagent_requests`) so a reader can see how much of a phase was
    delegated.

    Token counters and the context block stay MAIN-SESSION ONLY. The
    instruction floor and resident-token figures describe the measured
    session's own context window; folding a subagent's fresh context into
    them would make an approach that delegates heavily look like it carried
    a larger prompt. Subagent tokens are reported separately as
    `subagent_tokens`.
    """
    by_phase: Dict[str, dict] = {}
    residents: List[int] = []
    unpriceable: Dict[str, int] = {}
    subagent_models: Dict[str, int] = {}

    for entry in entries:
        if entry["type"] == "assistant":
            usage = entry["usage"]
            bucket = by_phase.setdefault(entry["phase"], _new_bucket())
            bucket["cost_usd"] += price_or_record(
                usage, entry["model"], pricing, unpriceable
            )
            bucket["requests"] += 1
            bucket["input_tokens"] += usage.get("input_tokens", 0)
            bucket["output_tokens"] += usage.get("output_tokens", 0)
            bucket["cache_write_tokens"] += usage.get("cache_creation_input_tokens", 0)
            bucket["cache_read_tokens"] += usage.get("cache_read_input_tokens", 0)
            residents.append(
                usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
            )

        sub_usage = entry.get("subagent_usage")
        if sub_usage:
            bucket = by_phase.setdefault(entry["phase"], _new_bucket())
            sub_model = entry.get("subagent_model")
            sub_cost = price_or_record(sub_usage, sub_model, pricing, unpriceable)
            bucket["cost_usd"] += sub_cost
            bucket["subagent_cost_usd"] += sub_cost
            bucket["subagent_requests"] += 1
            bucket["subagent_tokens"] += usage_token_total(sub_usage)
            name = canonical_model(sub_model) or "<missing model id>"
            subagent_models[name] = subagent_models.get(name, 0) + 1

    for bucket in by_phase.values():
        bucket["cost_usd"] = round(bucket["cost_usd"], 6)
        bucket["subagent_cost_usd"] = round(bucket["subagent_cost_usd"], 6)

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
        "subagents": {
            "requests": sum(b["subagent_requests"] for b in by_phase.values()),
            "cost_usd": round(
                sum(b["subagent_cost_usd"] for b in by_phase.values()), 6
            ),
            "tokens": sum(b["subagent_tokens"] for b in by_phase.values()),
            "models": subagent_models,
        },
        "unpriceable_models": unpriceable,
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
    assignment = assign_phases_with_fires(read_entries(transcript), phases)
    summary = summarise(assignment.entries, pricing)
    attribution = phase_attribution(phases, assignment.marker_fires)
    work_done = compute_work_done(cell, transcript)

    computed = sum(bucket["cost_usd"] for bucket in summary["by_phase"].values())
    reported = float(result.get("total_cost_usd") or 0.0)
    unpriceable = summary["unpriceable_models"]

    # An unpriceable model means `computed` is a known undercount, so the
    # reconciliation result cannot be trusted even if it happens to land
    # inside tolerance. Force the failure and name the model ids.
    within_tolerance = reconcile(computed, reported)
    ok = within_tolerance and not unpriceable

    notes = []
    if not within_tolerance:
        notes.append("computed cost drifted past tolerance; excluded from aggregates")
    if unpriceable:
        notes.append(
            "unpriceable model ids (no rate card, priced as $0 -- computed cost is an "
            "undercount): {0}".format(
                ", ".join(
                    "{0} ({1} turn{2})".format(name, count, "" if count == 1 else "s")
                    for name, count in sorted(unpriceable.items())
                )
            )
        )

    plugin_version = plugin_version_verdict(result, transcript)

    run = {
        "ticket": cell["ticket"],
        "approach": cell["approach"],
        "approach_id": cell.get("approach_id", cell["approach"]),
        "version": cell.get("version"),
        "plugin_version": plugin_version,
        # Preferred from result.json (what execute.py recorded at run time)
        # and falling back to cell.json. Both are written by provisioning; a
        # result.json from before this field existed has neither, and None
        # correctly reads as "this run predates plugin isolation" rather than
        # as "nothing was loaded".
        "environment": result.get("environment") or cell.get("environment"),
        "run_id": cell["run_id"],
        "session_id": result["session_id"],
        "total": {
            "reported_cost_usd": reported,
            "computed_cost_usd": round(computed, 6),
            "duration_ms": result.get("duration_ms"),
            "setup_seconds": result.get("setup_seconds"),
            "num_turns": result.get("num_turns"),
        },
        "billing_mode": billing_mode_from_result(result),
        "termination": termination_verdict(result, transcript),
        "by_phase": summary["by_phase"],
        "context": summary["context"],
        "subagents": summary["subagents"],
        "phase_attribution": attribution,
        "work_done": work_done,
        "reconciliation": {
            "ok": ok,
            "within_tolerance": within_tolerance,
            "tolerance": 0.02,
            "unpriceable_models": unpriceable,
            "note": "; ".join(notes),
        },
    }

    # Written unconditionally, before any exit-status decision: the session
    # has already been paid for, and a measurement failure must never cost
    # the operator the record of what was spent.
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(run, indent=2))

    if not run["termination"]["clean"]:
        print("FAILED CELL: " + run["termination"]["note"])

    if work_done["empty_diff"]:
        print("FAILED CELL: " + work_done["empty_diff_note"])

    if not plugin_version["ok"]:
        print("FAILED CELL: " + plugin_version["note"])

    status = "ok" if ok else "RECONCILIATION FAILED"
    print(
        "measured {0}: reported=${1:.4f} computed=${2:.4f} "
        "(subagents ${3:.4f} over {4} call(s)) [{5}]".format(
            cell["approach"],
            reported,
            computed,
            summary["subagents"]["cost_usd"],
            summary["subagents"]["requests"],
            status,
        )
    )
    if not attribution["available"]:
        print("WARNING: " + attribution["note"])
    if plugin_version["declared"] and not plugin_version["verified"]:
        print("WARNING: " + plugin_version["note"])
    for note in notes:
        print("WARNING: " + note)
    return (
        0
        if (
            ok
            and not work_done["empty_diff"]
            and run["termination"]["clean"]
            and plugin_version["ok"]
        )
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
