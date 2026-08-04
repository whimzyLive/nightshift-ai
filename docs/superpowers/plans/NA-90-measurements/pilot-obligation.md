# NA-90 Gate-3 pilot obligation

NA-90's own implementation run is NOT the pilot. Its domain dispatches executed on the
pre-change contract — the clause exists only after Phase 2 commits, after every dispatch
that could have honoured it. An after-number from this run would measure the OLD contract
while reading as if it measured the new one.

Pilot selection rule — the first story after this PR merges satisfying ALL of:

```text
ASSERT it dispatches >= 1 domain agent          # otherwise no subagent transcript exists to measure
ASSERT it is not NA-91, NA-92 or NA-93          # each changes read/context behaviour, confounding the delta
ASSERT it is a normal feature/defect story      # not a spec-only or plan-only run
```

Suggested default if none is queued: /sdlc:auto on NA-81 (plan-slicing, parked). Confounder to
record if used: NA-81 alters plan-doc read VOLUME, so report source-other separately from
self-generated-artifact.

The pilot MUST report, at minimum:

```text
net domain-agent read volume, est tok/story, before -> after      (GATE: >= 9,020 reduction)
carve-out hit rate, before -> after                                (a low rate with a passing
                                                                    aggregate is a FINDING, not a pass)
request-count delta                                                (reported, never a gate)
static instruction delta and its ratio to the 9,020 threshold      (~18%)
QA rounds / blocked rate / review findings                         (must not increase — NOT relaxed)
the corpus partition counts, recursive glob, subagent count > 0
```

Recorded in the merged PR body (AC-4) and posted as a comment on NA-90 (NA-88 tier-2 discipline),
so the obligation cannot be silently dropped. E's 4.9% cut-rate is NOT counted toward the
programme's AC-1 until this pilot passes every gate (AC-5).
