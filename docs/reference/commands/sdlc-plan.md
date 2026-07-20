---
title: '/sdlc:plan'
description: 'Produce an implementation plan for a Jira story. Creates branch, writes docs/superpowers/plans/ doc, raises PR, and links back to the story. Run after /spec PR is reviewed and merged.'
related-adrs: []
---

# /sdlc:plan

Produce an implementation plan for a Jira story. Creates branch, writes docs/superpowers/plans/ doc, raises PR, and links back to the story. Run after /spec PR is reviewed and merged.

---

**Source:** `plugins/sdlc/commands/plan.md`

## Step 0 — Issue-type guard (defects skip plan)

Before dispatching anything, probe the issue type — **defects have no plan phase**. Use the canonical
one-liner (same as `/auto` Step 0):

```bash
ITYPE="$(acli jira workitem view <STORY-KEY> --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

If `ITYPE == bug` → **STOP** with: `defects skip spec/plan — run /impl`. Do **not** create a
`plan/<STORY-KEY>` branch and do **not** dispatch the agent. Without this guard a Bug would
false-fail on "run `/spec` first" (step 2) because a defect never has a spec doc. (Defence-in-depth;
the `/auto` Step-0 gate + lightweight defect routing are the primary gate.) Otherwise continue.

---

Dispatch the `tech-lead` agent to produce an implementation plan for the Jira story.

The agent should:

1. Derive the spec path: `docs/superpowers/specs/<STORY-KEY>.md` — no Jira comment lookup needed
2. Verify the spec file exists (must be merged to develop); if missing, STOP and tell user to run `/spec <STORY-KEY>` first
3. Read the spec file at the derived path
4. Fetch Jira story using `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` with `<KEY>=<STORY-KEY>` for story summary and Epic context
5. Read CLAUDE.md to verify stack assumptions
6. Create and switch to branch `plan/<STORY-KEY>`
7. Break the spec into concrete, ordered, agent-tagged tasks saved to `docs/superpowers/plans/<STORY-KEY>.md`:
   - Phase 1 — `database-administrator` (schema + entities + migrations — ALWAYS FIRST)
   - Phase 2 — `platform-engineer` (backend infra + handlers + config)
   - Phase 3 — `sync-engineer` (only if spec has an offline-sync section)
   - Phase 4 — `web-engineer` (only if spec has Web UI section)
   - Phase 5 — `mobile-engineer` (only if spec has Mobile UI section)
   - `ai-enablement-engineer` — DEPENDENCY-FREE (plugins/**, skills/**, AI-config surface — only if
     plan has tasks) — may be dispatched at any point in the ladder above (first, between phases, or
     last): it consumes no artifacts from other domain agents and nothing consumes its; not part of
     the numbered serial sequence
   - All phases sequential — principal-engineer dispatches one agent at a time, never two at once;
     `ai-enablement-engineer` is the sole exception to phase **order** (may be dispatched anywhere in
     the sequence), not to serial execution — it still runs alone when dispatched
8. Each task must be completable without questions — include entity names, field names, route paths from spec
9. End each phase with a verification step (typecheck + lint + validate)
10. Commit the plan file, push the branch to remote, then raise PR:
    ```bash
    # Stage and commit
    git add <plan-file-path>
    git commit -m "docs(plan): <STORY-KEY> <story summary>"
    # Push BEFORE creating PR — PR creation fails if branch not on remote
    git push -u origin plan/<STORY-KEY>
    # Raise the PR atomically via raise-pr.sh (create + mark-ready + request @copilot + verify the
    # request attached). NEVER hand-roll gh pr create + add-reviewer separately — that is how the
    # reviewer step gets dropped. Write the body to the session-scoped temp dir, then pass by file.
    dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
    # write "$dir/pr-body.md" with your file-write tool, e.g.:
    #   Plan for <STORY-KEY>. See docs/superpowers/plans/<STORY-KEY>.md.
    PR_URL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/raise-pr.sh \
      "plan/<STORY-KEY>" develop "docs(plan): <STORY-KEY> <story summary>" "$dir/pr-body.md" --phase plan)
    ```
11. Comment the story. Use the real captured PR URL (must be a full `https://github.com/...` URL — not a placeholder):
    ```bash
    acli jira workitem comment create --key <STORY-KEY> \
      --body "Plan ready.
    File: docs/superpowers/plans/<STORY-KEY>.md
    PR: <PR_URL>"
    ```
12. Return: story key, plan file path, PR URL

## Final action — loop the PR to Copilot-clean, then release (when run standalone)

This step applies only when `/plan` is the **top-level** command. When `/auto` generates the plan as
part of Workflow A Phase 2 (it dispatches the `tech-lead` agent and ships the plan on the impl
branch), `/auto` owns the loop **and** the single session release at the very end — do **not** run
this final action nested.

After **everything above is complete** (the plan PR is raised and the Jira comment posted), the
standalone command's final action is to drive the Copilot review-fix loop on the just-raised PR to
convergence, **then** release — the loop is the session's **tail**:

```bash
# PR_URL is the plan PR captured from the agent (step 12). Drive the review-fix loop on it.
/loop /sdlc:loop <PR_URL>
```

The native `/loop` re-invokes `sdlc:loop` each pass: it polls Copilot's review of the PR head, runs
`/review-fix` inline on each round of comments, and exits when the head is Copilot-reviewed with no
unresolved comments and checks pass (or it halts / hits the idle budget). Because the loop is the
**tail**, its own "Final action — release the session" emits the single `session-complete` — do
**NOT** call `session-complete.sh` separately here.

> - If the harness cannot invoke the native `/loop` from inside a command, drive `sdlc:loop`'s
>   pass-cycle via `ScheduleWakeup` instead (same effect), then let its final pass release.
> - If the command hit a terminal STOP **before** a PR was raised (nothing to loop on), run
>   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` directly to release.

Jira story key (e.g. CER-123):
$ARGUMENTS
