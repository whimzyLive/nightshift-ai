---
title: Workflow — building a new feature
description: The path a new feature takes through the sdlc plugin, from a raw idea to merged code, and which command runs each step
related-adrs: [docs/adr/0001-two-phase-dispatch-founder-confirmation-gate.md]
---

# Workflow — building a new feature

This page follows one new feature from a raw idea to merged code. Each step names the command
that runs it, what it produces, and where a person has to act. For changing a feature that
already has stories, see [Workflow — editing an existing feature](workflow-editing-a-feature.md).

## At a glance

```text
idea
 │  /refine-feature "<idea>"        product-manager   → Jira Epic
 │  (you) set the Epic's AI Workflow mode
 │  /prd <EPIC>        (optional)   product-manager   → PRD PR, questions asked  (you merge)
 │  /design <EPIC> <export>         design PR         → docs/design/<slug>/      (you merge)
 │  /stories <EPIC>                 scrum-master      → stories + Blocks graph
 │  (you) set story points
 │  /auto <EPIC>                    epic session      → one PR per story
 ▼
merged code, stories Done
```

Every step before `/auto` writes either a Jira item or a docs PR. No product code is written
until `/auto`.

## 1. Idea → Epic — `/refine-feature`

`/refine-feature "<raw idea>"` dispatches the **product-manager**. It turns the idea into a Jira
Epic written in product language: the core idea, target users, the value, what it is not, and
open questions. Requester inputs are sorted into three sections on the Epic:

- **Design** — a `docs/design/<slug>/index.md` path. A design file not yet in the repo is never
  read; the command tells you to run `/design` for it.
- **Dev Notes** — implementation directives from the requester, kept verbatim.
- **References** — docs, links, other tickets.

**You:** set the Epic's **AI Workflow** mode (`Full Auto`, `Auto`, or `Assisted`, as a field or an
`AI-Workflow:<mode>` label). `/auto <EPIC>` refuses to start without it. The mode becomes the
default for every child story.

## 2. Epic → PRD — `/prd` (optional)

`/prd <EPIC>` writes `docs/features/<date>-<slug>.md`: the user story, 5–10 testable acceptance
criteria, user flows with edge cases, out-of-scope, open questions, dependencies, and the Epic's
Dev Notes and References carried over. Its design line reads `pending` until step 3 fills it in.

Before anything is committed, every open question the draft leaves is asked in your session, each
with a recommended answer first and `Leave open` last. Answers go into a `## Decisions` section
and are applied to the acceptance criteria, flows, and scope they change, so open feedback is
settled before the design and the stories build on it. Then it raises the PR and comments the path
on the Epic, with how many questions were resolved and how many stay open. An unattended run cannot
ask, so it leaves the questions in the PRD and lists them on the Epic for its author.

**You:** answer the questions, then review and merge the PRD PR.

**Skipping it.** For a feature the Epic already describes well enough, skip `/prd`. `/stories`
then decomposes from the Epic description and says so. You lose the question session and the
written flows, so the Epic's own open questions are still open when stories are written.

## 3. Design → `docs/design/` — `/design`

`/design <EPIC> <files>` ingests HTML exports, screenshots, or a handoff folder into
`docs/design/<slug>/`:

- `index.md` — one row per page or image, each described, with a headless render per page.
- `components.md` — the component inventory: every shared UI element marked `Reused`, `Changed`,
  or `New` against the project's UI library, with the gap for each.

It raises a design PR, links it on the Epic, and fills in the merged PRD's design line. **You:**
review and merge the design PR. Designing after the PRD means the design draws the flows and edge
cases the PRD settled. A design that already exists can be attached before `/prd` instead; the PRD
then links it directly. Either way, run it before `/stories`, so decomposition can place the right
part of the design on each story. A feature with screens but no design gets a warning from
`/stories`.

## 4. Stories — `/stories`

`/stories <EPIC>` runs the **scrum-master** in decompose mode. It maps the user journey, splits
the feature into stories, and creates them under the Epic:

- Each story follows the story template, carries its slice of the design in its **Design**
  section, and is labelled `AI-Ready` (already refined, so `/auto` skips re-triage).
- Dependencies become Jira `Blocks` links.
- When the inventory has `Changed` or `New` components, one **`UI-Components`** story is created
  first. It blocks every feature story that uses those components, so the components are built
  and merged into the library before any feature composes them.

**You:** set **story points** on every story. The scrum-master reports an estimate for each but
never writes the field. A story without points stops `/auto`.

## 5. Stories → merged code — `/auto <EPIC>`

`/auto <EPIC>` drives every child story, one at a time, in dependency order:

| Step | What happens                                                                                                                                 |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| E0   | Reads the Epic's AI Workflow mode; none set → refuses with a comment on the Epic                                                             |
| E0a  | Routes any merged design revision (nothing to do on a first build)                                                                           |
| E1   | Builds the queue from the `Blocks` graph; a cycle stops the run                                                                              |
| E0b  | **Spec preflight, in your session:** every full-path story gets its spec written and approved now, so the run after this is unattended       |
| E2   | Spawns one child session per story, running `/auto <STORY>`                                                                                  |
| E3   | `Full Auto` story → checks pass, PR merges, next story. Any other mode, or a `UI-Components` story → waits for you to merge, then `continue` |
| E4   | A child that fails or goes silent halts the epic; a re-run resumes at the story it stopped on                                                |

Each child run of `/auto <STORY>`:

1. **Assess** — `AI-Ready` stories skip the scrum-master check.
2. **Triage** — points at or under the lightweight threshold (project setting, default 3) → no
   spec; above it → full path. Bugs always take the debugging path.
3. **Spec** (full path only) — the spec approved in E0b is on `feat/<KEY>`. There is no separate
   plan by default: the spec's `## Implementation tasks` is the task list. A project that sets
   `Plan step` to `on` in its project context gets a tech-lead plan committed to the same branch
   first; it needs no approval, so it runs unattended too.
4. **Implement** — domain agents run in dependency order (database → backend → sync → web →
   mobile). `dep-gate.sh` holds a story whose blockers have not merged.
5. **QA, in session** — review, fix, re-review until clean and every acceptance criterion has
   evidence. Round 1 is the one full review; later rounds check only the fixes, and review stops
   after 3 rounds. Important findings still open at that point make the PR a **draft** that lists
   them, and it waits for you even in `Full Auto`.
6. **One PR** — spec (and plan, when on) and code together. Copilot review is advisory.
7. **Tail** — `Full Auto`: wait for checks, merge, move the story to Done. Otherwise the PR waits
   for you.

## Approving specs ahead of time

`/spec` settles every open question the spec raises with `AskUserQuestion` (recommended answer
first), writes each answer into the spec and its `## Decisions` section, and only asks for approval
once nothing is left open: an unattended run implements the spec as written and cannot ask.

To get a batch of complex stories ready before any run, approve them in one sitting:

- `/spec <EPIC>` — every child story that needs a spec and does not have an approved one, in
  dependency order (the same list `/auto <EPIC>` E0b would ask about).
- `/spec <KEY> <KEY> …` — the stories you name.

Each approved story carries `Spec-Approved` and its spec on `feat/<KEY>`, so an unattended
`/auto <KEY>`, a worker, or the epic run goes straight to implementation.

## A single story instead of an epic

For a one-off story, skip steps 1–4: `/refine-issue "<text>"` (or a key) produces a well-formed
story, you set its points, then `/auto <STORY>` runs the child flow above. On the full path the
spec is written and approved in that session, before implementation starts.

## Where you act

| When                                        | You                                              |
| ------------------------------------------- | ------------------------------------------------ |
| After `/refine-feature`                     | Set the Epic's AI Workflow mode                  |
| `/prd`                                      | Answer its open questions, then merge the PRD PR |
| After `/design`                             | Review and merge the design PR                   |
| After `/stories`                            | Set story points                                 |
| `/spec <EPIC>` or `/auto` E0b               | Answer the spec questions and approve each spec  |
| Non-`Full Auto` and `UI-Components` stories | Review and merge the PR, then type `continue`    |
