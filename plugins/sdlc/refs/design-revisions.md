# Design revisions — what changed, and which stories it reaches

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

A design edited after stories were written must reach exactly the stories it changes, with an exact
picture of the change. Nobody records hashes: the comparison point is always the design as merged on
the base branch — what every story so far was built against. Three roles carry this: `/design`
measures the change, the scrum-master routes it once merged, and every agent reads the diff first.

## Measuring — `design-diff.sh` (run by `/design` on a revision)

```text
old := docs/design/<slug>/ on origin/<BASE>        new := the same folder after this run's ingest + inventory
pages -> rendered in both versions (Playwright), diffed pixel by pixel
components -> each instance captured by selector, diffed on its own (immune to layout shifts above it)
images (screenshots, exported jpg/png) -> diffed directly
components.md -> row added/removed, Status change, Gap change
every visual change -> renders/diff/**/<name>.png  = Before | After | Diff (changed pixels red)
index.md -> "## Changed in this revision" block: | Change | Kind | Item | File | Pixels | Diff |
Revision := hash of the block's rows -> the same change always gets the same Revision
the block and renders/diff/ are replaced on every revision; git history keeps older ones
no Playwright -> byte compare: same rows, Pixels/Diff `-`, plus an `asset` row per changed file no row names
```

**Component selector** — `components.md` `Selector` column (optional, last): a CSS selector for the
component's root element as rendered. Empty → `[data-slot="<kebab-case name>"]` (shadcn marks each
rendered component that way); `none` → never captured. A component the script reports `UNCAPTURED`
→ `/design` writes a Selector that finds it on its `Used in` pages and re-runs the script once; still
uncaptured → leave it — its pages still diff whole.

## Routing — scrum-master Mode 4 (dispatched by `/auto <EPIC>` E0a, after the design PR merges)

Routing waits for the merge, so an abandoned design PR never touches Jira, and every path a story
names already exists on the base branch. It never swaps labels on an existing story: a story that
has started keeps its approved scope, and the change ships as a follow-up behind it.

```text
block := the Changed block of origin/<BASE>:<DESIGN_DIR>/index.md; Revision := its `Revision:` value
ASSERT block has rows AND the Epic has no comment "Design revision routed: <slug> <Revision>"   ELSE return "nothing to route"
images := `git show origin/<BASE>:<DESIGN_DIR>/<Diff>` into the session tmp dir -> Read each
reaches(row) := Epic children whose Design section names the row's File, or whose Dev Notes `Uses`
                the row's component; an `asset` row (fallback) reaches every story naming this design
started(S) := S has a spec (Spec-Approved, or a spec/plan on origin/<BASE>) | a feat/ or fix/ branch | an open PR | status is done
```

| Change reaches | Story | Action |
| --- | --- | --- |
| a component (`component` / `inventory` row) | Epic's `UI-Components` story not started and not `AI-Ready` | Add / widen its rows as ACs (`refs/ui-components.md`) |
| a component | `UI-Components` story started or `AI-Ready` | New story, labels `UI-Components` + `Design-Change`, layer L0; it `Blocks` every story the row reaches; an unmerged old components story `Blocks` it |
| a page / image / asset | not started | Comment the rows and Diff paths — it builds from the current design anyway; never rewrite it |
| a page / image / asset | started | New story, label `Design-Change`; the original `Blocks` it when not yet merged, else link `Relates` |

**A `Design-Change` story** (`refs/jira-story-template.md`; never re-specifies the original):
- **User story line:** As <the original persona>, I want <screen> to match the revised design, so
  that <the original outcome>.
- **ACs** — one per change the Diff images show, stated as the visible result (`The bank step's
  primary button reads "Send verification code"`); 3–6, split above 6.
- **Design:** each row's File **and** its Diff path; the original story's Design rows that still apply.
- **References:** `Revises <original key>` + `Design revision: <slug> <Revision>`.
- Points estimated as usual; no `AI-Ready` (refined, not triaged).

```text
open Design-Change story for the same original, not started -> update it, never a second
row reaches no story -> "unrouted" in the return (a page no story implements yet)
after routing -> comment the Epic "Design revision routed: <slug> <Revision>"
```

E0a runs before the queue is built, so the new stories join this run: E0b gets their specs approved
up front and `dep-gate.sh` holds each behind its blockers.

## Reading — every agent

```text
story Design section names a renders/diff/ image -> Read it FIRST: Before | After | Diff, red = changed
build what After shows; the Diff marks the only regions this story may change
Changed block row with Diff `-` -> compare `git show <sha>:<design_dir>/<File>` (<sha> from the block's `compared with … @ <sha>`) with the current file yourself
```
