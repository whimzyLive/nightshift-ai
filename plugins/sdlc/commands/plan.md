---
description: Produce an implementation plan for a full-path Jira story from its approved spec, committed to the story's feat/ branch (no PR of its own) so it ships in the implementation PR. Off by default — an approved spec's Implementation tasks are the task list. /auto and /impl run it only when project-context sets `Plan step` to `on`; run it by hand any time.
---

## Step 0 — Guards

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
ITYPE="$(acli jira workitem view <STORY-KEY> --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
git fetch origin --quiet
git cat-file -e origin/feat/<STORY-KEY>:docs/superpowers/specs/<STORY-KEY>.md 2>/dev/null && echo SPEC=yes || echo SPEC=no
bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess-ready.sh <STORY-KEY>   # SPEC_APPROVED=yes|no|unknown
```

- `ITYPE == bug` → **STOP**: `defects skip spec/plan — run /impl`. Dispatch nothing.
- `SPEC=no` or `SPEC_APPROVED` not `yes` → **STOP**: `no approved spec on feat/<STORY-KEY> — run /spec <STORY-KEY> first`.

No human gate: the plan only orders the approved spec's tasks, so it runs unattended too.

## Step 1 — Plan (tech-lead)

`<BASE-BRANCH>` := the `Base branch` row of `.claude/project/project-context.md`.

```bash
setup_out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh <STORY-KEY> feat/<STORY-KEY> <BASE-BRANCH>) || exit 1
WORKTREE=$(printf '%s\n' "$setup_out" | grep '^WORKTREE=' | cut -d= -f2-)
```

Dispatch the `tech-lead` agent in standard mode with `<STORY-KEY>` and `WORKTREE`. It reads the spec
in `$WORKTREE`, fetches the story (`${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md`), and writes
`$WORKTREE/docs/superpowers/plans/<STORY-KEY>.md`:

- Phases in ladder order, each task tagged `[agent-name]`: `database-administrator` (always first)
  → `platform-engineer` → `sync-engineer` (only with an offline-sync section) → `web-engineer` (only
  with a Web UI section) → `mobile-engineer` (only with a Mobile UI section). `ai-enablement-engineer`
  may sit anywhere; every phase still runs alone.
- Every task completable without questions — entity, field, and route names from the spec.
- Each phase ends with a verification step (typecheck + lint + validate).
- **Never commit, push, raise a PR, or write to Jira** — leave the file for Step 2.

## Step 2 — Commit to the story branch

```bash
git -C "$WORKTREE" add docs/superpowers/plans/<STORY-KEY>.md
git -C "$WORKTREE" diff --cached --quiet || git -C "$WORKTREE" commit -m "docs(plan): <STORY-KEY> <story summary>"
git -C "$WORKTREE" push -u origin feat/<STORY-KEY>
PLAN_SHA=$(git -C "$WORKTREE" rev-parse HEAD)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
acli jira workitem comment create --key <STORY-KEY> --body "Plan: docs/superpowers/plans/<STORY-KEY>.md @ $PLAN_SHA on feat/<STORY-KEY>. It ships in the implementation PR."
```

No PR is raised — the plan reaches review in the implementation PR. The Principal Engineer playbook
uses a plan doc in place of the spec's `## Implementation tasks` whenever one exists.

## Step 3 — Return

Story key, plan path, `PLAN_SHA`, the phases with their task counts.

## Final action — release (when run standalone)

Nested under `/auto` or `/impl`, the caller owns the terminal action. Standalone: no PR was raised,
so no **Session boundary at PR raise** applies — release bare:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Jira story key (e.g. CER-123):
$ARGUMENTS
