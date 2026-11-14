---
name: designing-in-patterns
description: Use when designing, planning or auditing UI against a component library — naming surfaces with the repo's pattern vocabulary, deciding reuse versus extend versus new, exploring compositions, or writing the reuse table (component-plan.md, a spec's `## Reuse`, a UI audit). Carries the design method; the repo's own vocabulary, bundle and board rules come from project-context and the designer override.
---

# designing-in-patterns — design method

**Core principle:** a screen is assembled from components that already exist. The library moves before the screen, and every decision to add a component is made once, here, by the designer — never by whoever builds the screen.

**Announce at start:** "I'm using the designing-in-patterns skill."

Repo-specific values (the vocabulary file, the bundle inventory folder, templates, board lint) are never named here: read them from the project-context `## Design` tokens and `.claude/project/agents/designer.md`.

## 1. Name every surface

```text
surface := every visible thing on a board or in a spec, one row per surface per screen
name    := a pattern from the `Pattern vocabulary` file, or `?` — never an invented name; on a wireframe it is the `data-pattern="<name>"` tag of the block, never a visible label
counts  := a name counts only when the `Bundle inventory` folder has that component (ls/Grep, never by reading component source)
vocabulary names a component the inventory lacks -> the surface is `?`, not that pattern
```

## 2. Two tests before a `?` becomes new

```text
second occurrence := Grep the app's UI paths for the pattern
                     present once as page code -> it is shared now: shared component AND a cleanup task in the same story ("Replace <path> with <Component>")
slot              := different children in an existing component meet the need -> reuse, note the slot; not new
neither applies   -> new
```

## 3. Extend or new

```text
extend := a new option on an existing component: a tone, a size, a slot
new    := a different structure or behaviour
```

An extension that needs a second rendering path inside the component is new; a new component that is the old one plus one option is an extension.

## 4. Explore rows

A row whose composition or feel the vocabulary does not settle is `Explore: yes`.

```text
2-3 shadcn compositions, each with phone and desktop behaviour and the keyboard behaviour they share
built as Storybook variant stories on the library branch (the `Component review` token serves them)
the human chooses before merge; losers are deleted in the same PR; only the winner reaches the bundle
never drawn by hand on a board
```

## 5. Reuse table

One format for `component-plan.md` and a spec's `## Reuse`:

```text
| Surface | Pattern | Template | Component | Action | Explore | Story |
```

| Column | Content |
| --- | --- |
| Surface | the visible thing as named on the draft (its `data-pattern` tag marks the pattern; `?` marks a gap) |
| Pattern | a vocabulary name; `?` only while unsettled, never in a committed plan |
| Template | the page template; `—` when the surface is not a page |
| Component | the bundle export (PascalCase); `—` when none |
| Action | `reuse` · `extend` · `new` |
| Explore | `yes` · `no` |
| Story | the library story key; `—` for `reuse` |

A `new` row with no Story is an open question; the spec cannot be approved with it.

## 5a. Controls inside a surface

A pattern name settles the block, not what is drawn inside it. Before a plan is final, every distinct control and every list or table row structure is checked against the real bundle and library.

```text
verdict := reuse (a named export) | shadcn (a named ui part) | in source, not exported | compose (named parts; shared already or not) | missing
anything but reuse | shadcn -> an open question with options and a recommendation; the human decides: extend, build new, export, accept the composition, or drop
a container being in the bundle says nothing about its rows, cells or items: check them by name
```

Table format and the rule: `refs/component-plan.md` "Controls checked".

## 6. Layering rules (the method respects these)

```text
slots not settings   := variation comes through children and slots, not a growing list of props
no data in layers 1-4:= primitives, ui components, composites and layouts take values by props; no fetching, no domain types
build downward       := a surface is built from layers below it; a higher layer never re-implements a lower one
shared the second time:= the second use of a pattern makes it shared (test 2)
everything in the bundle:= a component not exported to the design bundle does not exist for boards
```

## 7. Anti-patterns

| Anti-pattern | Instead |
| --- | --- |
| Naming a pattern the bundle lacks | Mark the surface `?` and run the two tests |
| A screen board introducing a component | Raise the library story first; the board mounts the bundle |
| className restyling of a shared component | Change the component for everyone (extend), or reuse it unchanged |
| A copy kept to pass a board | Fix the board or the component; never keep the copy |
| Choosing the composition by hand-drawing it | Explore row: variant stories, human picks |
