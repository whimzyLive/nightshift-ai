# Component plan — `docs/design/<slug>/component-plan.md`

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

Written by the `designer` agent in plan mode (`commands/design.md --plan`) from the approved drafts,
the pattern vocabulary and the bundle inventory. It is the join between a board and the component
library: one row per visible surface, saying which component builds it and whether that component
exists, and one row per control drawn inside those surfaces, checked against the real library. Principles: `refs/design-workflow.md`. Distinct from `components.md` (`refs/ui-components.md`),
which inventories a finished design's pages against the library exports.

## Inputs

```text
drafts     := the approved wireframe boards; a path the orchestrator hands in (downloaded from the canvas, or the temp dir); rows come from their `data-pattern` tags, `?` tags are the gaps
vocabulary := project-context `Pattern vocabulary` (a path): the fixed pattern names, each with its template or component
inventory  := project-context `Bundle inventory` (a folder): one entry per component the design bundle exports
ASSERT vocabulary and inventory exist ELSE STOP naming the missing token
a pattern name counts as "in the bundle" only when the inventory folder has that component -> checked with Grep/ls, never by reading component source
library    := project-context `UI library` (Tooling) and the optional `Bundle entry` (the file the bundle is built from); read only by scripts/library-exports.sh, for the control audit
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

## Controls checked

A pattern row is true at the level of the block: "List table -> ListTable, reuse" says nothing about
the rows inside the table or the picker inside a form card. A final board is the first place those
parts must be mounted, which is too late to find that one is missing. So plan mode audits every
control before the plan is settled and before any library story is raised.

```text
| Control | Seen on | Bundle/library check | Verdict | Q |
```

| Column | Content |
| --- | --- |
| Control | the kind, normalised, plus what it picks or shows ("Multi-select picker: people", "List table row: invoices"); one row per distinct control, not per occurrence |
| Seen on | every draft board that draws it; never empty |
| Bundle/library check | what was looked up and found: the export, ui part or source file, by name ("ListTable exported; ListRow, ListCell in source, not exported") |
| Verdict | `reuse` · `shadcn` · `in source, not exported` · `compose` · `missing` |
| Q | `—` for `reuse` and `shadcn`; otherwise the settled answer and its story key: `extend, <key>` · `new, <key>` · `export, <key>` · `accept composition` · `drop` |

```text
scan      := every draft fragment (the same approved boards the pattern rows come from), below the `data-pattern` level
kinds     := single select | multi select | picker or combobox | date or time input | toggle or segmented switch | chip group | stepper | file input | chart |
             tag or badge input | row and cell structure of each list or table | row actions | pager | tabs | sheet or dialog type | any other interactive or compound control
read from := the markup (`<input type>`, `<select>`, `role`, `<table>` rows and cells, svg charts, a repeated chip-with-remove, a chip group with an Add control) and the copy;
             judgement is allowed, a row with no `Seen on` board is not
check     := bash scripts/library-exports.sh [--match <regex>]   # EXPORTED: in the bundle; ENTRY_ONLY: mountable, no inventory entry; SOURCE_ONLY: in source, not exported
             plus the inventory folder for the component's documented parts and states, and the ui parts the designer override allows
             no `Bundle entry` row -> SOURCE_ONLY means only "no inventory entry": confirm against the bundle itself, as the override says, before writing `in source, not exported`
verdict   := reuse                    WHEN a named bundle export builds the control as drawn
           | shadcn                   WHEN a named ui part the bundle exports builds it unchanged
           | in source, not exported  WHEN the library has it and the bundle does not: say so in those words, name the file
           | compose                  WHEN several named parts build it together; say whether that composition already exists as a shared component
           | missing                  WHEN nothing in the bundle or the library builds it
a list or table row is its own control: the container being exported does not make its row and cell parts exported
verdict other than reuse | shadcn -> an open question (below), never settled by the designer alone
committed file: no row with a verdict other than reuse | shadcn and an unanswered Q; a `drop` row stays in the table, so the next reader sees it was decided
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

## Settling `?` rows and control questions

```text
open rows -> the agent returns them as `Q:` blocks (WHY: which surface/screen, OPTIONS: 2-3 pattern or component choices, recommended first); it never asks
open controls -> one `Q:` block per `Controls checked` row whose verdict is not reuse | shadcn (WHY: the control, its screens and what the check found;
                 OPTIONS, recommended first, from: extend <Component> | build new | export <Component> | accept the composition of <parts> | drop the control from the screens)
                 the answer decides the library story: extend, new and export raise one; accept composition and drop raise none
the command puts them to the user with AskUserQuestion, at most 4 per call, same model as commands/spec.md Step 2
answered -> the row's Pattern/Component/Action, or the control row's Q, are updated, then the plan is committed
unattended -> STOP (refs/design-workflow.md Human gates)
```

## Library stories

After the plan is settled and confirmed, the designer raises one story per `extend`/`new` row and per `Controls checked` row settled as `extend`, `new` or `export` (all grouped by Component: a control and a surface naming the same Component share one story) under the Epic. "Export an existing component" is a valid library story kind: the component is already built, the story puts it in the bundle.

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
export stories (a control settled as `export`), ACs instead of the first one above:
  - <Component> (and the parts its control row names) is exported from the design bundle, unchanged in behaviour
  - the remaining ACs above that apply: a Storybook story per state with a keyboard play test, the README line, the bundle card and a bundle sync run
control stories: Dev Notes := the control row (Control, Seen on, Bundle/library check); `Screens:` := its Seen on boards
write the key back into the plan's Story column, or the control row's Q column, commit
then the Epic's design story: bash scripts/design-story.sh <EPIC> ensure --plan <this plan> --description-file <file>   # refs/design-workflow.md "The design story"; created once, blocked by every library story
headless -> acli create can be refused by policy: propose the stories in a Jira comment on the Epic instead (the plan's Story column stays `—`)
```

Setting the `Library label` to `UI-Components` makes the library stories ride the existing hard block
(`refs/ui-components.md` Hard block: `dep-gate.sh` waits for a merged PR, E3 gates the epic after them).
Any other label still blocks `--final` through `scripts/library-blockers.sh`.

## Consumers

```text
scrum-master (Mode 1 step 2a, 6b, 6c, 6c1, 12a) := reads the plan when present: library stories exist already (reuse them, never a second one); screen stories get a Blocks link from every library story whose Screens names their board, and a `UI surfaces` line (pattern names)
                       the Epic's `Design` story, created by `/design --plan`, is reused and linked to block every screen story; Done already -> nothing is held (refs/design-workflow.md "The design story")
solutions-architect := copies the story's plan rows into the spec's `## Reuse` section (surface, template, component, action, story); an action `new` row with no Story is an open question the spec cannot be approved with
domain agent := receives the story's plan rows with its Design paths; builds the screen from the listed components; a row whose component does not behave as the board shows -> stop and report
designer (final mode) := a control settled as `accept composition` is drawn from the parts its row names and is not raised again
no plan for a UI Epic -> consumers fall back to components.md alone; nothing blocks
```
