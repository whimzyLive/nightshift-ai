# Design workflow — library first, drafts then finals

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

How a UI Epic goes from idea to screens built out of components that already exist. Run by
`commands/design.md` (`/sdlc:design <EPIC> --draft | --plan | --final`), executed by the `designer`
agent, closed by `/sdlc:ui-audit`. The repo-specific values (vocabulary, bundle, folders, canvas) are
the project-context `## Design` tokens (`refs/project-context-template.md`) and the repo's
`.claude/project/agents/designer.md`; nothing here names them.

## Why

A screen designed and built before its components exist makes its own copy of every pattern, and
nothing downstream notices the copies. The fix is ordering plus a check at each join: board, component
library, story.

## Principles

```text
1. Library first      := the library moves before the screen at every stage; a screen board never introduces a component — it waits for the library story
2. Two board kinds    := draft | final (below); a story's Design row may name finals only
3. Component wins     := a deliberate design change is made to the shared component for everyone, never as a per-page override;
                         a conflict found while building -> stop and report (domain-agent-handoff.md), never keep a copy
4. Pattern vocabulary := every visible surface carries one of the repo's fixed pattern names, or `?`;
                         a name counts only when the bundle has that component — checked against the inventory folder, never by reading
5. Two tests before a `?` becomes a new component:
     second occurrence := the pattern is already in the app once as page code -> it is shared; the old site is a cleanup task in the same story
     slot              := different children in an existing component meet the need -> not new
6. Nothing high-fidelity by hand := composition and feel are explored in code as variant stories on the library branch,
                         reviewed before merge, losers deleted in the same PR
```

## Board kinds

| Kind | What it is | Ingested | A story may name it |
| --- | --- | --- | --- |
| draft | greyscale wireframe: grey tokens only, no colour, no accuracy; phone and desktop frames where both matter; several layouts side by side allowed; every box labelled with a pattern name or `?` | never | no |
| final | a screen mounted only from the design bundle (the `Bundle global` token), strict board lint, built on a named template | yes, by the `--final` ingest | yes |

```text
kind is declared in the board page: <meta name="board-kind" content="draft|final"> and, on a final, <meta name="board-template" content="<template>">
index.md lists the declared kinds in its `## Boards` table (File | Board kind | Template); scripts/design-kind.sh reads it, a canvas.json or a page
no declared kind -> unknown: design-ingest.sh treats it as final and prints a NOTICE; consumers still treat unknown as not nameable by new stories
draft board lint := skipped by kind (it is a wireframe); final board lint := the repo's own board rules, plus: template mandatory,
                    no token-drawn shape the bundle already has, component key empty or all system components
```

## The flow

```text
Epic (+ PRD) -> draft -> [human approves drafts] -> plan -> [human settles `?` rows] -> library stories built and merged -> final -> ingest -> /stories
draft := one wireframe board per screen, pattern names or `?`
plan  := docs/design/<slug>/component-plan.md (refs/component-plan.md): what is reused, extended or new, and which rows need exploring
final := precondition: every library story under the Epic is Done (scripts/library-blockers.sh -> BLOCKERS= empty)
         screen boards mounted from the fresh bundle, then the existing ingest path of commands/design.md
```

Order against the rest of the pipeline: `/prd` (optional) -> `/design --draft` -> `/design --plan` ->
`/stories` (scrum-master reads the plan, creates the library stories first and the screen stories
blocked by them) -> library stories land -> `/design --final` -> screen stories build from finals.
When `/stories` already ran, `--plan` raises the library stories itself (component-plan.md "Library
stories") and the scrum-master links screen stories to them on its next pass.

## The explore step

A plan row marked `explore: yes` is a component whose composition or feel is not settled by the vocabulary.

```text
the library story builds 2-3 variants as Storybook stories (the repo's `Component review` token names the command that serves them)
the human reviews them on the library branch/PR; one wins
losers are deleted in the same PR before merge; only the winner reaches the bundle
no variant is drawn by hand on a board; a board shows the winner after it is bundled
```

## Human gates

| Mode | Gate | Interactive | Unattended (`SDLC_SESSION_KEY` set) |
| --- | --- | --- | --- |
| draft | approve the drafts on the canvas, or ask for another pass | AskUserQuestion after publishing | STOP: Jira comment `Design draft:` on the Epic, label `Design-Review`, bare release |
| plan | settle every `?` row; confirm the library stories before they are created | AskUserQuestion, same model as `/spec` Step 2 | STOP: Jira comment listing the open rows, label `Design-Review`, bare release |
| final | none beyond the docs PR review; preconditions are mechanical | STOP when `BLOCKERS=` is not empty | same STOP, with a Jira comment naming the blockers |

A label is a Jira-side signal only (like `Spec-Required` for `/auto` A0); removing it and re-running
the command resumes.

## Publishing is the orchestrator's job

```text
designer agent := never publishes; the canvas tool is available to the top-level session only (same rule as every domain agent)
orchestrator   := the command session; it publishes drafts and finals to the project-context `Design canvas`, following the doc named by `Publish recipe`
                  `Design canvas` unset | `Publish recipe` unset -> nothing is published; say "no design canvas configured" and hand the file paths back
                  the plugin never learns the canvas tool; the recipe doc owns it
approved drafts come back to disk: the orchestrator downloads them to a temp dir (scripts/tmp-dir.sh) and hands that path to plan mode
```

## Who reads what

| Role | Reads |
| --- | --- |
| scrum-master | `component-plan.md` at decompose: library stories, screen stories blocked by them, a `UI surfaces` line per story |
| solutions-architect | the story's plan rows -> the spec's `## Reuse` section |
| domain agents | the plan rows with the Design paths (principal-engineer playbook item 6); component wins over board |
| QA, AC verifier | finals only on Design rows; plan rows honoured; duplicates and restyles are Important findings (`refs/qa-review-rounds.md`, `refs/ac-verification.md`) |
| epic run | E0b: finals and library blockers Done before any UI child spawns; end of epic: `/sdlc:ui-audit` |
