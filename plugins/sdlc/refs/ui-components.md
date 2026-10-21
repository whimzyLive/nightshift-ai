# UI components ahead of features — contract

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

A design's shared UI components are built and merged into the project's component library **before**
any feature story that uses them starts. Feature stories compose those components; they never build
them. Four roles carry this: `/design` writes the inventory, the scrum-master turns it into a
components story, `dep-gate.sh` holds feature stories until that story merges, and the domain agent
builds the components standalone.

## Component library and Storybook (resolved by `/design` only)

```text
LIBRARY := project-context `UI library` row (Tooling)                       # a path, e.g. packages/ui/
         | the single workspace→agent row owned by web-engineer or mobile-engineer that is a shared
           package other workspaces import (not an app)
         | none -> no inventory, no components story; say "no UI library configured" in the return
library exports := the package entry point's exports (index.ts / package.json "exports")
STORYBOOK := yes WHEN `.storybook/` exists in LIBRARY or the repo root
                   | any `.storybook/main.*` whose stories glob reaches LIBRARY (e.g. apps/storybook/)
                   | `storybook` or `@storybook/*` is a dependency in LIBRARY's or the root package.json
           | no
```

Downstream roles never re-resolve these — they read the `components.md` header.

## Inventory — `docs/design/<slug>/components.md` (written by `/design`)

```text
Library: <LIBRARY>
Storybook: yes|no

| Component | Status | Library export | Gap | Used in |
```

| Column | Content |
| --- | --- |
| Component | PascalCase name the library will export |
| Status | `Reused` (exists, design matches) · `Changed` (exists, design needs more) · `New` (absent) |
| Library export | The existing export (`Reused`/`Changed`); `—` for `New` |
| Gap | `Changed`: exactly what is missing (variant, state, prop). `New`: props and every visible state. `Reused`: `—` |
| Used in | `File` values of this design's `index.md` rows that show it, comma-separated |

```text
component := a UI element that repeats across pages, or is a recognisable widget (button, badge, card, input, nav, table, dialog)
page-only layout (one hero, one section arrangement) -> not a component; leave it to the feature story
one row per component; no `|` inside cells; no TODO left
design matches an existing export but under a different name -> Reused, named by its export
inventory every page row of index.md, not only the rows described in this run
revision with --add -> merge into the existing file by Component: union Used in, widen Gap
revision replacing assets -> rewrite from every page row now in index.md
LIBRARY none -> do not write the file
```

## Components story (written by the scrum-master)

```text
rows := every Changed/New row across the Epic's designs' components.md files
same Component in several designs -> one row: union Gap; Used in entries qualified as <index.md path>#<File>
rows empty -> no components story
existing child of the Epic with label `UI-Components` (JQL `parent = <EPIC> AND labels = "UI-Components"`)
  -> reuse it: add missing rows as ACs only if it is not yet AI-Ready, else report the extra rows; never create a second
else -> ONE story: summary "UI components for <Epic summary>", label `UI-Components`
over 4 rows -> split by component group; every split story is labelled `UI-Components`
```

- **User story line:** As a developer building <feature>, I want its shared components in the library,
  so that feature stories compose them instead of rebuilding them.
- **ACs** — one per row: `<Component> is exported from <Library> with <Gap states/variants>, matching
  the design`; then `Every component above renders from props alone — no app data, routing or page
  context`; then, per the header, `Storybook: yes` → `Each component has a Storybook story per listed
  state` | `Storybook: no` → `Each component has a unit test per listed state`. A story always has 3–6.
- **Design:** the `components.md` path(s) + the `index.md` rows its rows' **Used in** names.
- **Dev Notes:** `Build in <Library> as standalone components; export each from the library entry point`.
- **Order and links:** created **first** (layer `L0`), so its key exists before any feature story is
  written. It `Blocks` every feature story whose Design rows appear in a row's **Used in**;
  dependency-graph rationale `shared UI components`.
- **Feature stories** using a `Changed`/`New` component: Dev Notes gets `Uses <Component> from
  <Library> (built by <components-story-key>) — do not reimplement`, naming the split story that owns
  that component; their ACs never restate component internals.
- **Triage of one story** (`/refine-issue`): find the Epic's `UI-Components` child; it exists → add the
  `Uses` Dev Note and the `Blocks` link (`--in <components-key> --out <story>`); none → no `Uses`
  note, flag "components story missing — run /stories <EPIC>".

## Hard block

`dep-gate.sh` treats a blocker labelled `UI-Components` as satisfied only by a **merged** `feat/` or
`fix/` PR (`PR: unmerged` otherwise), and prints `UI_BLOCKERS=`. A reused feature branch with a
non-empty `UI_BLOCKERS=` merges the base branch in before work starts — it may predate the merge.

Epic runs (`refs/epic-orchestration.md` E3): a story labelled `UI-Components` is always `gated`,
whatever its mode — the epic suspends after it until its implementation PR has merged, so dependents
never race it. A dependent that still stops on `PR: unmerged` re-runs with `/auto <KEY>` once the
components PR merges.

## Building a components story (domain agents)

```text
build in Library only; export each component from the library entry point
standalone := renders from props alone -> no app data fetching, router, global store or page context
every state the Gap lists -> reachable through props
Storybook: yes -> a stories file per component beside it, one named story per listed state, using the
                  project's existing story conventions; run the Storybook build target when one exists
Storybook: no -> one unit test per listed state
project tokens and conventions win over the mock's raw values (refs/design-references.md Authority)
```
