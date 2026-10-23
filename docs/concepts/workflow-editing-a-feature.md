---
title: Workflow — editing an existing feature
description: How a change reaches a feature that already has stories — a revised design, a changed requirement, a bug, or review feedback
related-adrs: []
---

# Workflow — editing an existing feature

A feature that already has stories can change in four ways. Each has its own path, and the rule
behind all of them is the same: **work that has started keeps its approved scope, and the change
ships as new work behind it.** For a feature's first build, see
[Workflow — building a new feature](workflow-new-feature.md).

| The change               | Path                                                   |
| ------------------------ | ------------------------------------------------------ |
| The design was revised   | `/design` again → merge → `/auto <EPIC>` routes it     |
| A requirement changed    | Edit the story, or file a new one with `/refine-issue` |
| Something is broken      | A Bug, then `/auto <BUG>`                              |
| A PR got review comments | `/review-fix <PR>`                                     |

## A revised design

This is the only path the plugin routes for you. You never record what changed: the comparison
point is always the design as merged on the base branch, which is what every story so far was
built against.

```text
edit the design
 │  /design <EPIC> <files>          measures the change   → design PR   (you merge)
 │  /auto <EPIC>
 │     E0a  scrum-master routes the change to the stories it reaches
 │     E1   queue rebuilt, new stories included
 │     E0b  specs for new stories approved in your session
 │     E2   stories run as usual; dep-gate holds each behind its blockers
 ▼
changed screens merged
```

### 1. Measure — `/design`

Re-running `/design` on a design folder that already exists is a revision. After ingesting, it
compares the new folder with the one on the base branch:

- Pages are rendered in both versions and compared pixel by pixel.
- Each component instance is captured by its selector and compared on its own, so a layout shift
  above it does not count as a change to it.
- Screenshots and exported images are compared directly; `components.md` rows are compared by
  Status and Gap.
- Every visual change gets a **Before | After | Diff** image under `renders/diff/`, with changed
  pixels in red.
- `index.md` gets a `## Changed in this revision` block listing each change. Its `Revision` value
  is a hash of the rows, so the same change always gets the same value and is never routed twice.

The design PR shows the block and the Diff images. **You:** review and merge it. Nothing touches
Jira before the merge, so an abandoned design PR has no effect.

### 2. Route — `/auto <EPIC>`, step E0a

The scrum-master reads the merged block and the Diff images, finds the stories each change
reaches (through their Design section, or a `Uses <Component>` Dev Note), and acts:

| The change reaches | Story state                       | Action                                                                                           |
| ------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------ |
| A page or image    | Not started                       | Comment with the change and Diff paths. It builds from the current design anyway                 |
| A page or image    | Started or merged                 | New `Design-Change` story. The original `Blocks` it until the original merges                    |
| A component        | `UI-Components` story not started | Rows added to that story                                                                         |
| A component        | `UI-Components` story started     | New `UI-Components` + `Design-Change` story, first in the queue, blocking the stories it affects |

A story counts as **started** once it has an approved spec, a branch, an open PR, or is done.
Labels on existing stories are never changed. A `Design-Change` story has one acceptance
criterion per visible change, links its Diff images, and references the story it revises. The
Epic gets a `Design revision routed: <slug> <Revision>` comment, so a re-run routes nothing new.

### 3. Build — the rest of the epic run

The new stories join the same run. E0b asks you to approve their specs, then the run continues as
it does for a new feature. Every agent opens a story's Diff image first: build what **After**
shows, and change only the regions the **Diff** marks.

**You:** set points on any new `Design-Change` story before the run reaches it, and merge gated
PRs as usual.

## A changed requirement

The plugin does not route requirement changes; you choose the story.

- **Story not started** — edit the story in Jira. To have it refined again, remove its `AI-Ready`
  label and run `/refine-issue <KEY>`; a story that still has `AI-Ready` is left untouched.
- **Story started or merged** — leave it alone and file the change as a new story:
  `/refine-issue "<what changes and why>"`, link it to the original, set points, and run
  `/auto <NEW-KEY>`.

## Something is broken

File a **Bug** (`/refine-issue` rewrites a rough report into the bug template). `/auto <BUG>`
always takes the lightweight path with systematic debugging on a `fix/<KEY>` branch: reproduce,
find the root cause, fix it, and prove the fix with a test. A Bug needs no story points.

## Review comments on a PR

`/review-fix <PR>` reads the review comments, keeps only the ones that hold for this codebase,
fixes those through the right domain agents, re-reviews the fixes, and replies on every thread:
accepted threads are resolved, rejected ones stay open with the reason. It does not open a new
PR. To re-run only the review loop on a branch, use `/review <KEY>`.
