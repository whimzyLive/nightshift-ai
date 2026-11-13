# Component plan — `docs/design/<slug>/component-plan.md`

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Written by the `designer` agent in plan mode (`commands/design.md --plan`) from the approved drafts,
the pattern vocabulary and the bundle inventory. It is the join between a board and the component
library: one row per visible surface, saying which component builds it and whether that component
exists. Principles: `refs/design-workflow.md`. Distinct from `components.md` (`refs/ui-components.md`),
which inventories a finished design's pages against the library exports.

## Inputs

```text
drafts     := the approved wireframe boards; a path the orchestrator hands in (downloaded from the canvas, or the temp dir); rows come from their `data-pattern` tags, `?` tags are the gaps
vocabulary := project-context `Pattern vocabulary` (a path): the fixed pattern names, each with its template or component
inventory  := project-context `Bundle inventory` (a folder): one entry per component the design bundle exports
ASSERT vocabulary and inventory exist ELSE STOP naming the missing token
a pattern name counts as "in the bundle" only when the inventory folder has that component -> checked with Grep/ls, never by reading component source
```

## Format

```text
# Component plan — <title>

Epic: <EPIC-KEY>
Drafts: <paths or canvas link>

| Surface | Pattern | Template | Component | Action | Explore | Story |
```

| Column | Content |
| --- | --- |
| Surface | the visible thing, named as on the draft (its block's `data-pattern`) ("Project header", "Invoice list row"); one row per surface per screen it appears on |
| Pattern | a vocabulary name, or `?` while unsettled |
| Template | the page template the screen is built on; `—` for a surface that is not a page |
| Component | the bundle component that builds it (PascalCase export); `—` when none |
| Action | `reuse` · `extend` · `new` (definitions: the skill) |
| Explore | `yes` · `no` |
| Story | the library story key once raised; `—` for `reuse`; screen stories are linked by the scrum-master later, so the row also records `Screens:` below |

```text
one row per surface; no `|` inside cells; no `?` left in the committed file (every `?` row is settled first)
under the table, per extend/new row: `Screens: <draft board names that use it>`   # the scrum-master turns these into Blocks links
two rows naming the same Component -> one library story, Gap and Screens unioned
```

## The method

The two tests, extend versus new, the explore step and the table's meaning live in the `designing-in-patterns` skill (`skills/designing-in-patterns/SKILL.md`); the designer loads it. Here: the file's shape, and what the plan's consumers do with it.

```text
second-occurrence cleanup -> listed in the row's library story as "Replace <path> with <Component>"
slot -> Action := reuse, with a trailing `Note:` line naming the slot
Explore: yes -> below the table, one block per row:
### Explore: <Component>
- Variant A: <shadcn parts> — phone: <behaviour>; desktop: <behaviour>
- Variant B: ...
Keyboard: <keys and focus order common to all variants>
```

## Settling `?` rows

```text
open rows -> the agent returns them as `Q:` blocks (WHY: which surface/screen, OPTIONS: 2-3 pattern or component choices, recommended first); it never asks
the command puts them to the user with AskUserQuestion, at most 4 per call, same model as commands/spec.md Step 2
answered -> the row's Pattern/Component/Action are updated, then the plan is committed
unattended -> STOP (refs/design-workflow.md Human gates)
```

## Library stories

After the plan is settled and confirmed, the designer raises one story per `extend`/`new` row (grouped by Component) under the Epic:

```text
acli jira workitem create (Story, --parent <EPIC>), label := project-context `Library label` (default `Library`)
description := refs/jira-story-template.md block; UI surfaces line := the row's Pattern; Design := the plan path + draft boards; Dev Notes := `Build in <UI library> as a standalone component` + the row's Gap
ACs (3-6):
  - <Component> is built from the shadcn parts <list>, renders from props alone, and covers every state in the plan row
  - a Storybook story per state with a keyboard play test (keys, focus order)
  - the library README has a line for <Component>
  - the bundle has a card for <Component> and the bundle sync has been run
  - explore rows: the variants are built as stories, the winner is chosen in review, the losers are deleted
  - cleanup rows: <old site> uses <Component>
write the key back into the plan's Story column, commit
headless -> acli create can be refused by policy: propose the stories in a Jira comment on the Epic instead (the plan's Story column stays `—`)
```

Setting the `Library label` to `UI-Components` makes the library stories ride the existing hard block
(`refs/ui-components.md` Hard block: `dep-gate.sh` waits for a merged PR, E3 gates the epic after them).
Any other label still blocks `--final` through `scripts/library-blockers.sh`.

## Consumers

```text
scrum-master (Mode 1 step 2a, 6b, 6c) := reads the plan when present: library stories exist already (reuse them, never a second one); screen stories get a Blocks link from every library story whose Screens names their board, and a `UI surfaces` line (pattern names)
solutions-architect := copies the story's plan rows into the spec's `## Reuse` section (surface, template, component, action, story); an action `new` row with no Story is an open question the spec cannot be approved with
domain agent := receives the story's plan rows with its Design paths; builds the screen from the listed components; a row whose component does not behave as the board shows -> stop and report
no plan for a UI Epic -> consumers fall back to components.md alone; nothing blocks
```
