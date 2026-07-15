---
description: Curate Architecture Decision Records under docs/adr/ — seed a founder-known pattern inline, or distill the accumulated learnings corpus into promotable ADR candidates. Runs the shared draft → propose-tags → founder-confirm → write → regenerate-index → commit/PR pipeline (refs/adr-pipeline.md) via the knowledge-engineer agent, with the founder-confirmation gate at this command layer.
---

## Modes (dispatched from `$ARGUMENTS`)

| Invocation              | Mode        | Corpus read?                                                    |
| ----------------------- | ----------- | --------------------------------------------------------------- |
| `/sdlc:adr "<pattern>"` | **seed**    | No — drafts inline from the founder-supplied pattern text only. |
| `/sdlc:adr --distill`   | **distill** | Yes — mines the learnings corpus for promotable candidates.     |

Both modes run the same shared pipeline (`${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md`); they differ
only in how the draft candidate(s) are sourced and (distill only) whether learnings are deleted.

If `$ARGUMENTS` is empty (no pattern, no `--distill`) → **STOP** with a usage message:
`usage: /sdlc:adr "<pattern>"  |  /sdlc:adr --distill`.

## Seed-mode `source-stories`

Seed mode formalizes a founder-known pattern inline — there is often no originating Jira story. A
seed-mode ADR MAY carry an empty or omitted `source-stories` list; it is not flagged incomplete.
See `${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md` §9 for the full scoping rule (the `writing-adrs`
`source-stories` checklist item applies to distill, not seed).

## Shared pipeline split across the dispatch boundary

The procedure — drafting, the distill evidence protocol, promotion criteria, index regeneration —
is defined once in `${CLAUDE_PLUGIN_ROOT}/refs/adr-pipeline.md`; this command owns only the flow
around the founder-confirmation gate, which a dispatched subagent cannot itself pause for.

**Phase 1** — dispatch the `knowledge-engineer` agent to draft & return (writes nothing):

- Pass the founder-supplied pattern text (seed) or the distill trigger (distill).
- Receive back: the drafted ADR(s), proposed `agents:` tags, and (distill) the per-candidate
  memory-entry deletion list.

**Founder-confirmation gate (command layer, in-session, between the two dispatches):**

- Present each drafted ADR, its proposed `agents` tags, and (distill) the exact memory entries
  slated for deletion per candidate. Wait for explicit founder confirmation — identical discipline
  to the `/sdlc:analyze` apply gate: no inline auto-apply path.
- The founder may edit tags, reject individual candidates, or adjust/veto specific deletions.
  **Confirmation covers drafts AND deletions together** — nothing is deleted that the founder did
  not see and approve.
- If the founder confirms nothing → write nothing, report the drafted candidates, and exit
  cleanly. No branch, no PR, no phase-2 dispatch.

**Phase 2** — dispatch `knowledge-engineer` again to write only the confirmed items:

- Assign the next `NNNN` and write each confirmed ADR.
- Regenerate `docs/adr/index.md` deterministically.
- (distill only) Delete the founder-confirmed learnings in the same PR.
- Commit via `conventional-commit`, push, and self-raise the PR via `gh` /
  `${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh`.

## Branch/PR naming

- **Seed** → branch `docs/adr-<slug>`, PR title `docs(adr): <decision title>`.
- **Distill** → branch `docs/adr-distill-<YYYY-MM-DD>`, PR title
  `docs(adr): distill <n> ADR(s) from learnings corpus`.

Both branch off `<BASE-BRANCH>` from `.claude/project/project-context.md` — never assume `main`.

## Command control flow

After the phase-2 PR is raised, drive the review loop to convergence exactly as `/spec` does:

```bash
/loop /sdlc:loop <PR_URL>
```

If the harness cannot nest `/loop` from inside a command, fall back to `ScheduleWakeup` to drive
`sdlc:loop`'s pass-cycle instead (same effect — the loop is the last thing the session does), then
let its final pass release. If the command hit a terminal STOP before a PR was raised (nothing to
loop on, e.g. empty `$ARGUMENTS` or the founder confirmed nothing), release the session directly.

## Error handling

| Scenario                                                             | Behavior                                                                                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Empty `$ARGUMENTS` (no pattern, no `--distill`)                      | STOP with the usage message.                                                                                        |
| Founder does not confirm at the gate                                 | Write nothing; report the drafted candidates and exit cleanly (no branch/PR, no phase-2 dispatch).                  |
| claude-mem tools absent in distill mode                              | Halt distill with a clear "claude-mem tools unavailable" message. Seed mode is unaffected.                          |
| claude-mem observation DB empty in distill mode                      | Non-fatal — continue on repo-native citations; note the empty DB.                                                   |
| No promotable candidates found in distill mode                       | Report "no candidates met the promotion criteria" and exit cleanly — no ADR, no PR.                                 |
| Distill promotes a `shared.md` learning but the ADR narrows audience | ADR is written; the `shared.md` entry is NOT deleted (audience-preservation rule); note it in the PR.               |
| `docs/adr/` does not exist yet (first ADR)                           | Create it; next number is `0001`.                                                                                   |
| ADR number collision/gap while listing `docs/adr/`                   | Always take `max(existing) + 1`; never reuse a number, including one retired by a superseded/rejected ADR.          |
| Attempt to edit an `accepted` ADR's substance                        | Refuse — write a new superseding ADR instead, per the `writing-adrs` immutability rule.                             |
| `gh` / `raise-pr.sh` failure                                         | STOP and surface the error — do not leave a half-written ADR without a PR; the write is on a branch and reviewable. |

Pattern text for seed mode, or `--distill` for distill mode:
$ARGUMENTS
