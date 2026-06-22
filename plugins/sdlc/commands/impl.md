---
description: Execute implementation for a Jira story by running the Principal Engineer playbook INLINE in this session (domain agents dispatched directly). Comments the PR back on the story. Triages first — full stories require a merged plan PR; lightweight (<= threshold pts) stories implement directly with no plan precondition.
---

Execute the implementation for the Jira story **`$ARGUMENTS`** by running the Principal
Engineer playbook yourself, in the current (top-level) session.

**Do NOT dispatch a `principal-engineer` subagent.** Claude Code blocks subagent → subagent
nesting, so a dispatched principal-engineer cannot dispatch the domain agents it needs and will
return blocked. Orchestration must run at the top level, where the `Agent` tool works. You play
the Principal Engineer role directly.

## Steps

1. **Triage gate.** Run the triage step by **applying `${CLAUDE_PLUGIN_ROOT}/refs/triage.md` INLINE**
   (in this same session) and capture `TRIAGE` (`lightweight` | `full`). This decides whether the
   merged plan file is a hard precondition (Step 2). `STORY_POINTS=missing` resolves to `TRIAGE=full`
   (fail-safe). If the triage step **STOPs without emitting a `TRIAGE=` line** (e.g. an `acli`
   auth/DNS failure), **STOP** here and surface that error — do NOT proceed to implementation without
   a valid triage decision.

   > **Do NOT invoke the `/triage` slash command here.** Its final action runs `session-complete.sh`,
   > which under the automation harness emits the session-complete sentinel and releases this worker
   > slot mid-`/impl`. `/impl` owns the single release at the very end. Apply the **ref** inline,
   > never the **command** (`refs/triage.md` emits no sentinel).
2. Derive the plan path: `docs/superpowers/plans/<STORY-KEY>.md` — no Jira comment lookup needed.
   Whether the plan file is **required** depends on `TRIAGE`:
   - **`TRIAGE=full`** → the plan file MUST exist at that path (merged to `develop`). If missing →
     return **blocked**: tell the user to run `/spec <STORY-KEY>` then `/plan <STORY-KEY>` and merge
     the plan PR first (AC-2). No branch, no domain agents.
   - **`TRIAGE=lightweight`** → the plan file is **optional**: a missing
     `docs/superpowers/plans/<STORY-KEY>.md` is **NOT a blocker**. Proceed directly to the Principal
     Engineer playbook; it derives tasks from the story description. This is the **same direct path**
     `/auto` Workflow B takes for a lightweight story — neither command generates a plan doc on this
     path. The ONLY lock relaxed here is the plan-file STOP — the dependency gate below still runs.
3. Fetch the Jira story using `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>` for the
   summary, description, and context (comments, linked tickets, attachments).
4. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md` inline**, start to finish, for
   `<STORY-KEY>` — passing **`LIGHTWEIGHT=true` when `TRIAGE=lightweight`** (else `false`). That flag is
   what makes the playbook skip the plan-file STOP and derive tasks inline from the story on the
   lightweight path; on the full path it leaves the merged-plan precondition intact.
   That playbook is the single source of truth for the implementation workflow:
   pre-flight → branch → ordered domain-agent dispatch (`isolation: "worktree"`) → per-phase
   push/verify → **hand off to the QA Engineer** (`${CLAUDE_PLUGIN_ROOT}/refs/qa-engineer-playbook.md`, run
   inline: code-review loop until clean → memory writes → quality gate → AC/plan verification) →
   PR on a `clean` QA verdict. Dispatch domain agents and the QA loop with the `Agent` tool from
   THIS session. Capture the PR URL it produces as `IMPL_PR_URL`.
5. When the playbook completes, comment the PR on the story (use the real captured URL — a full
   `https://github.com/...`, never a placeholder):
   ```bash
   acli jira workitem comment create --key <STORY-KEY> \
     --body "Implementation complete.

PR: <IMPL_PR_URL>

All phases done. Review clean. Quality gate passed."
   ```
   (`comment add` does not exist in this acli version — use `comment create --key`.)
6. Report back: phases completed, the PR URL, review rounds, quality-gate evidence, any blockers
   or open items for the reviewer.

**IMPORTANT:** On the `full` path, only run after the plan PR is reviewed and merged (Step 2). On
the `lightweight` path, no plan PR is required. Either way this makes real code changes across
domain agents and cannot be easily undone. If the playbook hits `Status: blocked` at any phase,
STOP and surface it — do not improvise around it.

**Dependency gate (Step 1 of the playbook):** before any work, run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/dep-gate.sh <STORY-KEY>` — it resolves the parent epic, reads `<STORY-KEY>`'s
Jira `Blocks` links (by sibling-inversion) and requires every blocker to already have a
`feat/<blocker>` PR (open or merged). `GATE=STOP` (exit 1) → the whole flow STOPs and REJECTs —
no branch, no domain agents — and the `REASON=` line says which upstream story must ship first.
Do not bypass this.

## Final action — loop the PR to Copilot-clean, then release (when run standalone)

This step applies only when `/impl` is the **top-level** command. When `/auto` runs the
implementation as part of Workflow A Phase 2 (it executes the Principal Engineer playbook inline on
the `feat/<STORY-KEY>` branch), `/auto` owns the loop **and** the single session release at the very
end — do **not** run this final action nested.

After **everything above is complete** (the implementation PR is raised and commented on the story),
the standalone command's final action is to drive the Copilot review-fix loop on the just-raised PR
to convergence, **then** release — the loop is the session's **tail**:

```bash
# IMPL_PR_URL is the PR the Principal Engineer playbook opened. Drive the review-fix loop on it.
/loop /sdlc:loop <IMPL_PR_URL>
```

The native `/loop` re-invokes `sdlc:loop` each pass: it polls Copilot's review of the PR head, runs
`/review-fix` inline on each round of comments, and exits when the head is Copilot-reviewed with no
unresolved comments and checks pass (or it halts / hits the idle budget). Because the loop is the
**tail**, its own "Final action — release the session" emits the single `session-complete` — do
**NOT** call `session-complete.sh` separately here.

> - If the harness cannot invoke the native `/loop` from inside a command, drive `sdlc:loop`'s
>   pass-cycle via `ScheduleWakeup` instead (same effect), then let its final pass release.
> - If the command hit a terminal STOP/blocked **before** a PR was raised (nothing to loop on), run
>   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` directly to release.

Jira story key (e.g. <STORY-KEY>):
$ARGUMENTS
