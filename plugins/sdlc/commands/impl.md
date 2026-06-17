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

1. **Triage gate.** Invoke `/triage <STORY-KEY>` (apply `${CLAUDE_PLUGIN_ROOT}/refs/triage.md`) and
   capture `TRIAGE` (`lightweight` | `full`). This decides whether the merged plan file is a hard
   precondition (Step 2). `STORY_POINTS=missing` resolves to `TRIAGE=full` (fail-safe). If `/triage`
   **STOPs without emitting a `TRIAGE=` line** (e.g. an `acli` auth/DNS failure), **STOP** here and
   surface that error — do NOT proceed to implementation without a valid triage decision.
2. Derive the plan path: `docs/superpowers/plans/<STORY-KEY>.md` — no Jira comment lookup needed.
   Whether the plan file is **required** depends on `TRIAGE`:
   - **`TRIAGE=full`** → the plan file MUST exist at that path (merged to `develop`). If missing →
     return **blocked**: tell the user to run `/spec <STORY-KEY>` then `/plan <STORY-KEY>` and merge
     the plan PR first (AC-2). No branch, no domain agents.
   - **`TRIAGE=lightweight`** → the plan file is **optional**: a missing
     `docs/superpowers/plans/<STORY-KEY>.md` is **NOT a blocker**. Proceed directly to the Principal
     Engineer playbook; it derives tasks from the story description (the same way `/auto` Workflow B's
     tech-lead does with `LIGHTWEIGHT=true`). The ONLY lock relaxed on this path is the plan-file
     STOP — the dependency gate below still runs.
3. Fetch the Jira story using `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>` for the
   summary, description, and context (comments, linked tickets, attachments).
4. **Execute `${CLAUDE_PLUGIN_ROOT}/refs/principal-engineer-playbook.md` inline**, start to finish, for
   `<STORY-KEY>`. That playbook is the single source of truth for the implementation workflow:
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

## Final action — release the session (required)

After **everything above is complete** (success, or a terminal STOP/blocked surfaced to the user), run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It prints the completion signal the automation worker watches for, so the worker releases this session's slot immediately instead of waiting for the idle timeout. Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. <STORY-KEY>):
$ARGUMENTS
