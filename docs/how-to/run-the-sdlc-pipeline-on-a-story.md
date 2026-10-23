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

Drive one Jira story from a raw ticket to a merged PR. Two routes get you there: the one-shot `/sdlc:auto`, which triages the story and runs the right flow end to end, or the individual commands run by hand. For why the pipeline is shaped this way, see [docs/concepts/what-is-the-sdlc-plugin.md](../concepts/what-is-the-sdlc-plugin.md); for the whole path from an idea, see [docs/concepts/workflow-new-feature.md](../concepts/workflow-new-feature.md).

## Prerequisites

- `acli` authenticated against the Jira instance, and `gh` authenticated against the repo (both set up by `/sdlc:init`). acli's active site is checked against this repo's configured `Jira site` (in `project-context.md`) and switched automatically when it differs, so keeping more than one acli account signed in is safe in normal use — but an account must exist for this repo's site, or a command stops with `run: acli jira auth login --site <site>`.
- A Jira story key (e.g. `NA-123`). A Bug key also works and routes to the defect path automatically.
- Story points set on the story. Routing depends on them: at or under the lightweight threshold (per-repo, default `3`, inclusive) triages **lightweight**, above triages **full**. A Bug needs no points (it forces lightweight).
- For `/sdlc:auto` to auto-merge, the story's **AI Workflow** field set to `Full Auto`. Any other value (or unset) leaves the PR open for a human merge.

## Route A: one-shot with `/sdlc:auto`

```
/sdlc:auto NA-123
```

`/auto` assesses the story, triages it, and branches:

- **Lightweight story** (at or under the threshold, or any Bug) implements directly from the story: no spec, no plan. One `feat/NA-123` (or `fix/NA-123` for a Bug) PR.
- **Full story** needs an approved spec first. If the story has none, `/auto` writes it in this session, asks you every open question with a recommended answer, and waits for your explicit approval. It commits the spec to `feat/NA-123`, then implements on the same branch. Spec and code ship in **one** PR. There is no plan step unless the project's `Plan step` row is `on`, in which case a tech-lead plan is committed to the same branch first.

Either way, QA runs in the session (review → fix → re-review until clean, quality gate, every acceptance criterion evidenced) before the PR is raised. Copilot review on the PR is advisory. In `Full Auto` the PR merges once checks pass and the story moves to the pipeline done status; otherwise it waits for you.

An unattended run (a worker or an epic child) cannot ask for approval: a full story without an approved spec stops and is labelled `Spec-Required`. Approve specs ahead of time with `/sdlc:spec` (below).

To drive a whole **Epic** and every child story in dependency order, pass the epic key: `/sdlc:auto NA-100`. It approves every needed spec up front, then runs each child unattended.

## Route B: manual, one command per phase

1. **Refine the ticket** into a well-formed story (skip if the story is already clean):

   ```
   /sdlc:refine-issue NA-123
   ```

2. **Spec** (full stories only). Writes the spec in this session, settles every open question with you, and records your approval: label `Spec-Approved`, spec committed to `feat/NA-123`, no PR of its own. Pass several keys, or an Epic key, to approve a batch in one sitting:

   ```
   /sdlc:spec NA-123
   /sdlc:spec NA-123 NA-124      # several stories
   /sdlc:spec NA-100             # every child of the Epic that needs a spec
   ```

3. **Plan** (optional). Orders the approved spec's tasks into a tech-lead plan, committed to the same `feat/NA-123` branch. `/auto` and `/impl` run it themselves when `Plan step` is `on`; run it by hand any time:

   ```
   /sdlc:plan NA-123
   ```

4. **Implement.** Full stories need the approved spec from step 2; lightweight stories need nothing. Runs the Principal Engineer playbook inline — domain agents in dependency order, the QA loop, then one PR carrying the spec, any plan, and the code, commented back on the story:

   ```
   /sdlc:impl NA-123
   ```

5. **Drive review to green.** Re-run the review loop by hand only if you need another pass, or to review without re-implementing:

   ```
   /sdlc:review NA-123      # one review→fix→re-review cycle against the fix/ or feat/ branch
   /sdlc:loop <PR-URL>      # keep looping a specific PR until review-clean and checks pass
   ```

   `/sdlc:review` with no key runs Diff mode against the current working changes vs `develop`.

Once the PR is review-clean and checks pass, merge it to `develop`.

## Verify

- **Jira comments.** The story gets `Spec approved: … @ <sha>`, `Plan: … @ <sha>` (when a plan ran), and `Implementation complete … PR: <url>`. A missing comment means that phase did not finish.
- **PR link.** The implementation comment carries a full `https://github.com/...` URL. Follow it to confirm the PR is open and checks are green.
- **Story status.** In `Full Auto`, a completed story transitions to the pipeline done status after the merge. If it is still open, the merge was refused or checks failed, and the PR was left open for a human.

See the [/sdlc:auto](plugins/sdlc/commands/auto.md), [/sdlc:spec](plugins/sdlc/commands/spec.md), [/sdlc:plan](plugins/sdlc/commands/plan.md), [/sdlc:impl](plugins/sdlc/commands/impl.md), and [/sdlc:loop](plugins/sdlc/commands/loop.md) command references for the full flag list and async-review options — this guide covers only the path from a story to a merged PR.
