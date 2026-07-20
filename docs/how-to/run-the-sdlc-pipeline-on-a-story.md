---
title: How to run the full sdlc pipeline on a story
description: Take one Jira story from a raw ticket to a merged PR, using either the one-shot /sdlc:auto command or the manual step commands.
source:
  - plugins/sdlc/commands/auto.md
  - plugins/sdlc/commands/spec.md
  - plugins/sdlc/commands/plan.md
  - plugins/sdlc/commands/impl.md
  - plugins/sdlc/commands/loop.md
related-adrs: []
---

# How to run the full sdlc pipeline on a story

Drive one Jira story from a raw ticket to a merged PR. Two routes get you there: the one-shot `/sdlc:auto`, which triages the story and runs the right flow end to end, or the individual commands run by hand when you want to gate each phase yourself. For why the pipeline is shaped this way, see [docs/concepts/what-is-the-sdlc-plugin.md](docs/concepts/what-is-the-sdlc-plugin.md).

## Prerequisites

- `acli` authenticated against the Jira instance, and `gh` authenticated against the repo (both set up by `/sdlc:init`).
- A Jira story key (e.g. `NA-123`). A Bug key also works and routes to the defect path automatically.
- Story points set on the story. Routing depends on them: `<= 3` points (inclusive, per-repo threshold) triages **lightweight**, above triages **full**. A Bug needs no points (it forces lightweight).
- For `/sdlc:auto` to auto-merge unattended, the story's **AI Workflow** field set to `Full Auto`. Any other value (or unset) drives the PR to review-clean and leaves it open for a human merge.

## Route A: one-shot with `/sdlc:auto`

Use this when you want the pipeline to pick the flow and run it.

```
/sdlc:auto NA-123
```

`/auto` assesses story quality, triages complexity, and branches:

- **Lightweight story** (`<= 3` pts, or any Bug) implements directly. No spec, no plan doc, no review gate. It derives tasks inline from the story, runs implementation, raises one `feat/NA-123` (or `fix/NA-123` for a Bug) PR, and drives the review-fix loop.
- **Full story** runs in two phases:
  1. **Spec.** Generates the spec only, raises a `spec/NA-123` PR, drives it review-clean, then stops.
  2. **Plan + impl.** Re-run `/sdlc:auto NA-123` after the spec PR merges to `develop`. `/auto` detects the merged spec and continues: it generates the plan and the implementation on **one** `feat/NA-123` branch and raises a **single** PR containing both.

The spec PR merge is the resume point. In `Full Auto` mode the merge is automatic and Phase 2 kicks off on its own; otherwise merge the spec PR yourself, then re-run the command.

At each phase `/auto` posts a Jira comment with the clickable PR link before it enters the review loop. On a `Full Auto` clean loop exit it auto-merges the PR and, for the story-completing PR, transitions the story to the pipeline done status.

To drive a whole **Epic** and every child story in dependency order, pass the epic key instead: `/sdlc:auto NA-100`. Child stories each run their own single-story `/auto` flow.

## Route B: manual, one command per phase

Use this for a full story when you want to review and merge each artifact before the next phase starts. Skip this entire route for a lightweight story or a Bug — run `/sdlc:impl NA-123` directly (it triages, implements, and loops in one step), or just use Route A.

1. **Refine the ticket** into a well-formed story (skip if the story is already clean):

   ```
   /sdlc:refine-issue NA-123
   ```

2. **Spec.** Produces the design spec on a `spec/NA-123` branch, raises the PR, comments it on the story, and drives it review-clean:

   ```
   /sdlc:spec NA-123
   ```

   Review and **merge the spec PR to `develop`** before continuing.

3. **Plan.** Reads the merged spec and produces the implementation plan on a `plan/NA-123` branch, raises the PR, and drives it review-clean:

   ```
   /sdlc:plan NA-123
   ```

   `/plan` STOPs if the spec doc is not merged to `develop`. Review and **merge the plan PR** before continuing. (Note: unlike Route A, the manual path ships plan and impl as separate PRs.)

4. **Implement.** Requires the merged plan doc. Runs the Principal Engineer playbook inline — domain agents in dependency order, QA review loop, then a `feat/NA-123` PR, commented back on the story:

   ```
   /sdlc:impl NA-123
   ```

5. **Drive review to green.** `/impl` already runs the review-fix loop as its tail. Re-run the loop by hand only if you need another pass, or to review without re-implementing:

   ```
   /sdlc:review NA-123      # one review→fix→re-review cycle against the fix/ or feat/ branch
   /sdlc:loop <PR-URL>      # keep looping a specific PR until review-clean and checks pass
   ```

   `/sdlc:review` with no key runs Diff mode against the current working changes vs `develop`.

Once the impl PR is review-clean and checks pass, merge it to `develop`.

## Verify

- **Jira gate comments.** Each phase posts a comment on the story with the PR link and phase status (`Spec PR ready`, `Plan ready`, `Implementation complete`). A missing comment means the phase did not reach its PR step.
- **PR links.** Every comment carries a full `https://github.com/...` URL, not a placeholder. Follow it to confirm the PR is open, Copilot-reviewed, and checks are green.
- **Story status.** In `Full Auto`, a completed story transitions to the pipeline done status after the final merge. If it is still open, the loop halted (review-fix blocked, CI red, or idle budget) and the PR was left open for a human.

See the [/sdlc:auto](plugins/sdlc/commands/auto.md), [/sdlc:spec](plugins/sdlc/commands/spec.md), [/sdlc:plan](plugins/sdlc/commands/plan.md), [/sdlc:impl](plugins/sdlc/commands/impl.md), and [/sdlc:loop](plugins/sdlc/commands/loop.md) command references for the full flag list, review-gate configuration, and async-review options — this guide covers only the path from a story to a merged PR.
