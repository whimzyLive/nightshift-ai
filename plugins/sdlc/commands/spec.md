---
description: Write a technical spec for a Jira story IN THIS SESSION, settle every open question with you, and record your approval. The approved spec is committed to the story's feat/ branch (no PR of its own) and ships in the implementation PR alongside the code. Takes one or more story keys, or an Epic key to approve every child spec up front, so the stories can then run unattended under /auto. /auto runs this for every full-path story before implementing.
---

## Input

`$ARGUMENTS` := one or more story keys, or one Epic key.

- **Epic** (`issuetype` epic) → `KEYS` := the Epic's E0b `NEEDS` list
  (`${CLAUDE_PLUGIN_ROOT}/refs/epic-orchestration.md` E0b — build it with `epic-queue.sh` as E1 does;
  `GATE=STOP` → **STOP** with its `REASON`). Empty → "every spec under <EPIC> is approved or not
  needed", release bare.
- **Story keys** → `KEYS` := them, in the order given.

Run Steps 0–4 for each key in `KEYS`, in order; never skip ahead into implementation. A key that
STOPs or is not approved → Epic input: stop here (later specs may rely on it; a re-run resumes at
it); story keys: report it and go on to the next.

## Step 0 — Guards

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
ITYPE="$(acli jira workitem view <STORY-KEY> --fields issuetype --json 2>/dev/null \
           | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')"
```

- `ITYPE == bug` → **STOP**: `defects skip spec — run /impl`.
- `SDLC_SESSION_KEY` set (an unattended worker or epic child — nobody can answer or approve) →
  **STOP**: post `Spec approval required before implementation — run /spec <STORY-KEY> or /auto
  <STORY-KEY> interactively.` on the story, add label `Spec-Required`, release bare.

## Step 1 — Write the spec (inline — never a subagent)

The spec is approved by a human in this session, so it is never dispatched. Read
`${CLAUDE_PLUGIN_ROOT}/agents/solutions-architect.md` and follow it as yourself: required skills,
input validation, source-of-truth rules, first steps, the output structure, accuracy rules and
self-review. Path: `docs/superpowers/specs/<STORY-KEY>.md`. It already exists on
`origin/feat/<STORY-KEY>` → revise it there instead of STOPping.

The spec ends with **`## Implementation tasks`** — the task list the implementation runs from (there
is no separate plan): one `- [<agent>] <task>` line per task, in ladder order
(database-administrator → platform-engineer → sync-engineer → web-engineer → mobile-engineer;
`ai-enablement-engineer` anywhere), each naming the files or modules it touches.

## Step 2 — Settle open questions with the user

Every open question, ambiguity, and decision the spec flags goes to `AskUserQuestion` — at most 4
per call, the recommended default as the first option labelled `(Recommended)`. Write each answer
into the spec where it applies (data model, API, UI, tasks), and record it under `## Decisions`. An
answer that raises a new question → ask it in the next call. Nothing open → skip.

The spec leaves this step with **no open questions, TODOs, or "to be decided" left** — an
unattended `/auto` implements it as written and cannot ask.

## Step 3 — Approval gate

Summarise the spec (data model, API surface, UI, the task list by agent, out of scope) and ask with
`AskUserQuestion`: **Approve spec for <STORY-KEY>?** — `Approve (Recommended)` | `Request changes`.
Changes → revise, then ask again. Never continue without an explicit Approve, and never ask while
the spec still has an open question (back to Step 2).

## Step 4 — Commit to the story branch and record the approval

`<BASE-BRANCH>` := the `Base branch` row of `.claude/project/project-context.md`.

```bash
setup_out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-setup.sh <STORY-KEY> feat/<STORY-KEY> <BASE-BRANCH>) || exit 1
WORKTREE=$(printf '%s\n' "$setup_out" | grep '^WORKTREE=' | cut -d= -f2-)
# write/move the spec into "$WORKTREE/docs/superpowers/specs/<STORY-KEY>.md", then:
git -C "$WORKTREE" add docs/superpowers/specs/<STORY-KEY>.md
git -C "$WORKTREE" diff --cached --quiet || git -C "$WORKTREE" commit -m "docs(spec): <STORY-KEY> <story summary>"
git -C "$WORKTREE" push -u origin feat/<STORY-KEY>
SPEC_SHA=$(git -C "$WORKTREE" rev-parse HEAD)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/jira-site-guard.sh || exit 1
acli jira workitem edit --key <STORY-KEY> --labels "Spec-Approved" --remove-labels "Spec-Required" --yes
acli jira workitem comment create --key <STORY-KEY> --body "Spec approved: docs/superpowers/specs/<STORY-KEY>.md @ $SPEC_SHA on feat/<STORY-KEY>. It ships in the implementation PR."
```

No PR is raised — the spec reaches review in the implementation PR, next to the code it describes.
A later edit to an approved spec → remove `Spec-Approved` and run this command again.

## Step 5 — Return

Per key: spec path, `SPEC_SHA`, the branch, and the decisions recorded in Step 2 — or why it
stopped. Approved stories are ready for an unattended `/auto <KEY>` (or the epic run): A0 finds the
approval and goes straight to implementation.

## Final action — release (when run standalone)

Nested under `/auto`, `/auto` owns the terminal action. Standalone: no PR was raised, so
no **Session boundary at PR raise** applies — release bare:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

Outside the worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

Story key(s) or an Epic key (e.g. CER-123 CER-124, or CER-100):
$ARGUMENTS
