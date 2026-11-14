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
4. Pattern vocabulary := every surface is named with a pattern or `?`, and `?` passes two tests before it is new; the method is the
                         `designing-in-patterns` skill (skills/designing-in-patterns/SKILL.md), the single home of those rules
6. Nothing high-fidelity by hand := composition and feel are explored in code as variant stories on the library branch,
                         reviewed before merge, losers deleted in the same PR
```

## Board kinds

| Kind | What it is | Ingested | A story may name it |
| --- | --- | --- | --- |
| draft | Balsamiq-style wireframe built from the plugin's kit (`refs/wireframe-kit/`), one linked board per screen; every structural block tagged `data-pattern` with a pattern name or `?` | never | no |
| final | a screen mounted only from the design bundle (the `Bundle global` token), strict board lint, built on a named template | yes, by the `--final` ingest | yes |

```text
kind is declared in the board page: <meta name="board-kind" content="draft|final"> and, on a final, <meta name="board-template" content="<template>">
index.md lists the declared kinds in its `## Boards` table (File | Board kind | Template); scripts/design-kind.sh reads it, a canvas.json or a page
no declared kind -> unknown: design-ingest.sh treats it as final and prints a NOTICE; consumers still treat unknown as not nameable by new stories
draft board lint := skipped by kind; drafts are checked by scripts/wireframe-check.sh instead (below); final board lint := the repo's own board rules, plus: template mandatory,
                    no token-drawn shape the bundle already has, component key empty or all system components
```

## The flow

```text
Epic (+ PRD) -> draft -> [human approves drafts] -> plan -> [human settles `?` rows and control questions] -> library stories built and merged -> final -> ingest -> /stories
draft := one linked, playable wireframe board per screen in journey order, `data-pattern` names or `?`; written to a temp dir, never the repo
plan  := docs/design/<slug>/component-plan.md (refs/component-plan.md): what is reused, extended or new, and which rows need exploring
         control audit: every control and list row the drafts draw is checked against the bundle and the library (its `Controls checked` table);
         a control that is not a clean reuse is an open question, so a gap is settled here and never first found on a final board
final := precondition: every library story under the Epic is Done (scripts/library-blockers.sh -> BLOCKERS= empty)
         screen boards mounted from the fresh bundle, then the existing ingest path of commands/design.md
```

Order against the rest of the pipeline, the default: `/prd` (optional) -> `/design --draft` ->
`/design --plan` (raises the library stories, component-plan.md "Library stories", and the Epic's
design story, below) -> library stories built and merged -> `/design --final` (its PR merges, a person
closes the design story) -> `/stories` (each screen story names its final board from the start) ->
screen stories build from finals. Library first, then designs, then stories: `/stories` runs last.

`/stories` may also run before the final: the plan already names the library stories and the screens.
The screen stories then exist before their boards, and `/stories` links each one to the design story
the plan created, which keeps them from starting early. The order of the work does not change: library
stories, then `/design --final`, then the screen stories.

## The design story

```text
what     := one story per Epic: `High-fidelity designs for <EPIC> (final boards from the bundle)`, label `Design`, never `AI-Ready`
created  := by `/design <EPIC> --plan`, once the library stories are raised: scripts/design-story.sh ensure --plan <component-plan.md>
            at plan time no screen story and no final board exists: it is created from the plan alone, blocked by the library stories, blocking nothing
            a plan with no extend/new row (no library story) still gets one, blocked by nothing; a plan with no surface row has no screen and gets none
            idempotent: a second plan run and `/stories` reuse and relink it, a second is never created
            `/stories` creates one only as a fallback: a plan exists, the Epic has no design story, and a screen story has no final board to name
description := the story template (refs/jira-story-template.md); the user-story line is for the person who signs off the designs;
            Design := the plan path and the draft boards; `UI surfaces` := `None`; ACs:
            (1) a final board exists for every screen in the component plan, one per target in `Wireframe targets` (web, phone), mounted only from the design bundle
            (2) `docs/design/<slug>/index.md` lists every board with kind `final` and its template
            (3) the repo's Design check and board lint pass on every board (when project-context sets `Design check`)
            (4) each screen story's Design section names its final board
            (5) the boards are published to the design canvas and match the merged files, no drift (when a canvas is configured)
            (6) the design PR is merged
links    := blocked by every library story under the Epic (made at plan time, completed on every later run)
            `/stories` links it to block every UI screen story (a `UI surfaces` line that is not `None`, or web/mobile UI work)
            a story with `UI surfaces: None` (backend, contract, engine) is not blocked by it
            already Done when `/stories` runs (the default order) -> the screen stories name their final boards in their Design row and need no gate:
            the links are still made and a Done blocker holds nothing; still open -> the screen stories are blocked by it
closed   := by a person. `/design <EPIC> --final` comments it `Final boards: <index.md> | PR: <url>` when the design PR is raised and on each revision;
            the person moves it to Done when that PR merges. Nothing transitions it automatically
enforced := scripts/dep-gate.sh, run by `/auto` (Step 0b), `/impl` and `/run`: an open Design blocker stops the story with
            "run /sdlc:design <EPIC> --final first"; only Done satisfies it, never a PR
            a Bug is not held by it; `/auto <the design story>` is refused; an epic run builds what it does not block, then stops (E2a2)
```

## Wireframe drafts

Rules for draft mode; the kit, class vocabulary and working-folder layout are `refs/wireframe-kit/README.md`.

```text
journey map   := first, the ordered screens and, per control that navigates, its target screen; one journey per run; A/B layouts only when the user asks for another pass
boards        := kit classes only (inline layout allowed), real context-appropriate copy, no emoji; links are `<a href="<screen>.html">` styled as the button, so the journey plays in a plain browser
shell         := written once per run as parts/shell.* (browser frame nav, phone bottom nav) with the project's real nav items; assembled into every page by scripts/wireframe-build.sh, never pasted
targets       := project-context `Wireframe targets`: web (default when the row is absent) | phone | web, phone
                 web -> browser-frame boards; phone -> device-frame boards; both -> every screen of the journey, empty and error states included, also gets a phone board (no web-only screens), phone boards link among themselves
states        := the main path, plus the empty state and the main error state of a screen where they exist; the rest wait for finals
tags          := every structural block carries `data-pattern="<vocabulary name>"` or `?`; no visible label; `--plan` reads the tags
notes         := `.sticky` for an open question or a rule a reviewer should see on the board
canvas        := when one is configured it is the only copy; the temp folder is a hand-off, deleted after publish, and another pass starts from a fresh download so hand edits survive
project parts := shell + one starter per page template of the vocabulary, generated on the project's first --draft run, reused after; the vocabulary's optional `Wireframe` column names the kit classes that draw a pattern, a row without one is a plain `.sk` box
checks        := scripts/wireframe-check.sh runs in the designer before it returns and in the orchestrator before it publishes
return        := `Design draft:` Jira comment lists screens in journey order, the patterns used and each gap; controls that go nowhere are named as not linked
```

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
| plan | settle every `?` row and every control-audit question; confirm the library stories (the control-audit ones included) before they are created | AskUserQuestion, same model as `/spec` Step 2 | STOP: Jira comment listing the open rows, label `Design-Review`, bare release |
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

### What a publish recipe covers for wireframes

The plugin names the outcome; the recipe doc (project-context `Publish recipe`) owns how a canvas does it.

```text
kit assets      := wireframe.css and strokes/*.svg uploaded once per canvas and referenced by every board, not copied into each; the font link kept
link rewriting  := each `<a href="<screen>.html">` rewritten to the canvas's own board target, so the journey plays there; the standalone pages keep the plain hrefs
layout          := one page per Epic named `<EPIC> wireframes`; web boards left to right in journey order, phone boards in a row beneath
kind            := marked draft and interactive; an Approve drafts review happens here
shell           := recovered from the downloaded boards; a separate "Wireframe kit" page is optional, not required
round trip      := the recipe says how to download boards back into the designer's working-folder form (fragments and shell parts, hand edits and `data-pattern` tags intact); another pass and plan mode read them
no canvas       := nothing is published; the command keeps the temp folder and hands back the paths of the standalone pages
```


### What a publish recipe covers for final boards

```text
pages           := named Epic key first: `<EPIC> <Epic title>` for finals, `<EPIC> wireframes` for drafts, one kit page for shared parts
earlier page    := a page an earlier design left under the same name is renamed `Archived - <EPIC> earlier boards` before the new page is created; never reused or merged
name clash      := canvases are often flat (no slug folder), so the orchestrator compares the final boards' names (the designer's return lists them) with the files already on the canvas BEFORE publishing
                   a clash -> STOP and ask the user: replace in place after reading the old copy | move the old one aside | publish only the non-colliding boards
hand edits      := a board the user may have edited by hand is read before it is replaced
stale mounts    := the orchestrator lists boards on the canvas that mount components the new bundle no longer exports and reports them; it does not fix other boards unless asked
```

## Who reads what

| Role | Reads |
| --- | --- |
| scrum-master | `component-plan.md` at decompose: library stories, screen stories blocked by them, a `UI surfaces` line per story, the plan-created design story linked to every screen story |
| solutions-architect | the story's plan rows -> the spec's `## Reuse` section |
| domain agents | the plan rows with the Design paths (principal-engineer playbook item 6); component wins over board |
| QA, AC verifier | finals only on Design rows; plan rows honoured; duplicates and restyles are Important findings (`refs/qa-review-rounds.md`, `refs/ac-verification.md`) |
| epic run | E0c: finals and library blockers Done before any UI child spawns; E2a2: an open design story holds the stories it blocks; end of epic: `/sdlc:ui-audit` |
