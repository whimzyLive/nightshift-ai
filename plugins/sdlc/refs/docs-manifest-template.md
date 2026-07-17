# `docs-manifest.md` template

Template for the consumer-repo artifact `.claude/project/docs-manifest.md`, written by
`/sdlc:init` Step 4g on the docs opt-in. It is a **separate sibling file** to
`refs/doc-types.md` (decided — founder review, PR #112): never a section inside `doc-types.md`,
and never inside `refs/project-context-template.md`.

## Header comment

The written manifest carries this header comment verbatim (fill `<project name>` from the
collected Step 3 value; on a Merge-new-findings run where Step 3 did not run this pass, use the
project name already stored in `.claude/project/project-context.md` instead):

```markdown
<!--
  docs-manifest.md — scaffolded by /sdlc:init for <project name>.
  This file activates /sdlc:docs: each row in the table below is one doc type that /sdlc:docs
  will generate. To deactivate a doc type, set enabled = false — that is the stable way to turn
  it off without losing the row. Deleting a row instead does NOT permanently deactivate it: a
  future re-init will offer to re-append it unless the offer was previously declined and recorded
  (see the Decline record convention below). This file may also carry an optional "Voice & format"
  free-form section below the table (see refs/docs-manifest-template.md) — the row table itself
  remains 3-column activation data only, never generation logic, a schedule, or a runtime
  directive.
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

## Voice & format (optional, free-form)

Beyond the 3-column row table, the written manifest MAY carry one additional, free-form prose
section the founder authors by hand, below the table:

```markdown
## Voice & format

<free-form notes: voice, tone, terminology, and target output format — e.g. "Mintlify MDX with
this front-matter schema: ...", "second person, no marketing language", repo-specific terminology
to prefer or avoid>
```

This section is consumed by `plugins/sdlc/skills/writing-docs/SKILL.md`'s voice/format
resolution (`.claude/project/docs-manifest.md` is its first-choice source, falling back to
`.claude/project/project-context.md`, then a stated default). It is **not** part of the
3-column row-table activation data and is **not** validated by the Registry self-check in
`refs/doc-types.md` — it is optional prose, present only once a founder has written it.
`/sdlc:init` never writes or touches this section — the row table above is the only thing
`/init` fills or merges; this section is populated by hand (or by a future tool), never by
`/init` itself.

## Fill rules

- One row per `refs/doc-types.md` row whose `applies-when` matches the detected stack (v1: every
  row, since all 15 mandatory rows use `applies-when = always`).
- No `<...>` placeholder token may remain in a written manifest — every `<type>` and
  `<target-path>` slot above is filled with a real value before the file is written.
- `enabled` defaults to `true` for every newly-written row.
- `target-path` is pre-filled with the matching registry row's `target-path` default; the
  founder edits it later to point at their real docs tree.
- `/init` only ever writes or merges the row table (and the header comment) — it never adds,
  edits, or removes the optional "Voice & format" section; that section is entirely founder-owned.

## Decline record convention

On a re-run merge (`/sdlc:init` Step 4g, existing-manifest path), a registry row the founder
declines to append is recorded with a comment line, so subsequent re-runs read it and skip
re-offering that type:

```markdown
<!-- declined: <type>[, <type>...] -->
```

One comment line may list multiple declined types, comma-separated. This line is the only record
of a decline — declining does not write (and never overwrites) a disabled row for that type.
