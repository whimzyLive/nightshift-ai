---
id: completion-marker-cannot-silently-widen-its-fields
agent: [ai-enablement-engineer]
trigger: [extending a session/release completion marker, harness re-invocation protocol, appending a field to an existing sentinel line]
rule: A completion marker built to carry one fact can't grow new fields in place — a consumer's greedy field regex swallows the addition; ship new data as a separate, additive line instead.
evidence: [NA-91]
uses: 0
status: active
---

## Why

NA-91 needed the harness to re-invoke the review-fix loop with `--phase <GATE_PHASE>` and an
`--on-clean` auto-merge hook after a session-boundary release, but
`plugins/sdlc/scripts/session-complete.sh`'s existing marker
(`<<<SDLC_SESSION_COMPLETE:KEY|PR=URL>>>`) only carries the PR URL. Appending a field to that same
line (e.g. `|NEXT=...`) would break any consumer parsing `PR=(.+)` greedily — the new field would be
swallowed into the captured PR URL, silently corrupting it. Printing the new data (`<NEXT>`) on its
own separate `<<<SDLC_NEXT_INVOCATION:...>>>` line is additive and backward-compatible by
construction: the existing marker and its regex are untouched, and a harness that doesn't yet read
the new line simply doesn't get the extra behaviour (rather than getting corrupted data). ADR 0018
records the specific decision; this rule is the generalizable shape — it applies to any fixed-format
sentinel a downstream consumer parses positionally or with a greedy regex, not just this marker.
