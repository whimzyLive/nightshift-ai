# `docs-manifest.md` template

Template for the consumer-repo artifact `.claude/project/docs-manifest.md`, written by
`/sdlc:init` Step 4g on the docs opt-in. It is a **separate sibling file** to
`refs/doc-types.md` (decided — founder review, PR #112): never a section inside `doc-types.md`,
and never inside `refs/project-context-template.md`.

## Header comment

The written manifest carries this header comment verbatim (fill `<project name>` from the
collected Step 3 value):

```markdown
<!--
  docs-manifest.md — scaffolded by /sdlc:init for <project name>.
  This file activates /sdlc:docs: each row below is one doc type that /sdlc:docs will generate.
  To deactivate a doc type without losing its row, set enabled = false. Removing a row entirely
  also deactivates it. This file is declarative activation data only — it carries no generation
  logic, no schedule, and no runtime directive.
-->
```

## Row table

The manifest row table carries **exactly 3 columns**, in this order:

| Column        | Meaning                                                                                                                           |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `type`        | The registry key — must match a `type` value in `refs/doc-types.md`                                                               |
| `enabled`     | `true` (default) or `false`; set `false` to deactivate this doc type without deleting the row                                     |
| `target-path` | Editable output path; `/init` writes the registry's default `target-path` token, the founder retargets it to their real docs tree |

```markdown
| type   | enabled | target-path   |
| ------ | ------- | ------------- |
| <type> | true    | <target-path> |
```

`trigger`, `generation-mode`, `public`, and `quadrant` are **NOT** columns in this manifest —
consumers derive all four from `refs/doc-types.md` at read time. This is the single source of
truth; none of these four attributes is ever duplicated into the manifest.

## Fill rules

- One row per `refs/doc-types.md` row whose `applies-when` matches the detected stack (v1: every
  row, since all 15 mandatory rows use `applies-when = always`).
- No `<...>` placeholder token may remain in a written manifest — every `<type>` and
  `<target-path>` slot above is filled with a real value before the file is written.
- `enabled` defaults to `true` for every newly-written row.
- `target-path` is pre-filled with the matching registry row's `target-path` default; the
  founder edits it later to point at their real docs tree.

## Decline record convention

On a re-run merge (`/sdlc:init` Step 4g, existing-manifest path), a registry row the founder
declines to append is recorded with a comment line, so subsequent re-runs read it and skip
re-offering that type:

```markdown
<!-- declined: <type>[, <type>...] -->
```

One comment line may list multiple declined types, comma-separated. This line is the only record
of a decline — declining does not write (and never overwrites) a disabled row for that type.
