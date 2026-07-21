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
  (see the Decline record convention below). This file may also carry, below the table, an
  optional "Reference roots" section, an optional "Voice & format" free-form section, and an
  optional "Additional Jira project keys" free-form section (all described in
  refs/docs-manifest-template.md) — the row table itself remains activation data only (3 required
  columns plus 2 optional trailing columns, `source` and `contract`), never generation logic, a
  schedule, or a runtime directive.
-->
```

## Row table

The manifest row table carries the 3 **required** columns below, plus 2 **optional** trailing
columns (blank when unused, so an existing 3-column manifest stays valid unchanged):

| Column        | Meaning                                                                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`        | The registry key — must match a `type` value in `refs/doc-types.md`                                                                                   |
| `enabled`     | `true` (default) or `false`; set `false` to deactivate this doc type without deleting the row                                                         |
| `target-path` | Editable output path; `/init` writes the registry's default `target-path` token, the founder retargets it to their real docs tree                     |
| `source`      | **Optional.** A path, glob/scan directive, or `command:`-prefixed command feeding the source resolver's rung-2 (`refs/docs-pipeline.md` §3)           |
| `contract`    | **Optional.** An explicit contract-file path overriding the resolver's rung-1 conventional lookup (`refs/docs-pipeline.md` §3's Contract conventions) |

```markdown
| type   | enabled | target-path   | source     | contract   |
| ------ | ------- | ------------- | ---------- | ---------- |
| <type> | true    | <target-path> | <optional> | <optional> |
```

`trigger`, `generation-mode`, `public`, and `quadrant` are **NOT** columns in this manifest —
consumers derive all four from `refs/doc-types.md` at read time. This is the single source of
truth; none of these four attributes is ever duplicated into the manifest. `source` and `contract`
are still activation data (they tell the resolver where to look), never generation logic.

## Reference roots

Beyond the row table, the manifest MAY carry one additional, optional repo-level section
activating the four artifact-reference doc types (`command-reference`, `agent-reference`,
`skill-reference`, `hooks-contract`; see `refs/doc-types.md`'s "Doc-type families"):

```markdown
## Reference roots

reference-roots: <comma-separated dirs the artifact-reference scan walks; omit for a product repo>
reference-excludes: <comma-separated globs excluded from the scan; omit if none>
```

- **Convention default: absent `reference-roots` → the four artifact-reference rows never
  activate.** This is the product-repo default — a repo that authors no Claude Code artifacts
  configures nothing here and simply never gets artifact-reference pages.
- **`reference-excludes` is a global exclusion guarantee** — applied by the source resolver on
  **every** rung that walks a glob or a scan directive (the artifact-scan rung, and any glob/scan
  `source:` such as `error-reference`'s cross-root scan), not only the artifact-scan rung. It is a
  no-op for a rung that resolves a single explicit file (a path-valued `contract:` or path-valued
  `source:`).
- Neither field is validated by the Registry self-check in `refs/doc-types.md` (that section
  governs the registry, not the manifest) — this section's own Fill rules below are its
  validation.

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

## Additional Jira project keys (optional, free-form)

Beyond the 3-column row table, the written manifest MAY carry one more additional, free-form line
the founder authors by hand, below the table (and below "Voice & format" if both are present):

```markdown
## Additional Jira project keys

<comma-separated list of legacy or secondary Jira project keys, e.g.: ET>
```

Consumed only by `/sdlc:docs release`'s merged-story enumeration
(`refs/docs-pipeline.md` §10's "Story-key extraction") to widen the set of recognised story-key
prefixes beyond the single primary key in `.claude/project/project-context.md` — for a repo whose
history carries commits under more than one Jira project key (most commonly after a Jira project
rename or a repo merge), so those commits' stories are not silently dropped from the changelog. Not
part of the 3-column row-table activation data, and not validated by the Registry self-check in
`refs/doc-types.md`. `/sdlc:init` never writes this section **autonomously** and never invents its
content; it **may** write the exact additional keys a founder supplies at the fresh-write offer
(Step 4g's "If absent" path, validated key-shaped, no stub or placeholder). A blank offer, and
**every** merge-path run, leave the section untouched — so a founder who deleted it never gets it
silently re-appended. Its absence is not an error: `release` simply falls back to the single primary
project key (or, if that is also absent, a documented-risk loose regex — see §10). Because init never
writes a stub or example here, the only text ever parsed from a consumer manifest is the founder's
own — §10's resolution additionally ignores HTML comments and whitespace.

## Fill rules

- One row per `refs/doc-types.md` row whose `applies-when` matches the detected stack. For the
  narrative/release/`llms-txt` rows this is still every row (`applies-when = always`). For the
  activation-gated reference rows, `/init` pre-fills the row (recording founder intent) using the
  inputs it can evaluate at scaffold time (repo-detect + declared dependencies, and a conventional
  contract path actually found on disk for `api`/`schema`/`config`) — the manifest-dependent inputs
  (`reference-roots:present`, a configured `source:`/`contract:`) are not yet knowable while the
  manifest itself is being written, so a row's **live activation** is always re-resolved per
  `/sdlc:docs` run against the manifest's own values, never frozen at init-fill time. This matches
  locked decision 7: a plain product repo that configures nothing still gets contract-detected
  product docs once a real contract lands on disk.
- No `<...>` placeholder token may remain in a written manifest — every `<type>` and
  `<target-path>` slot above is filled with a real value before the file is written. `source` and
  `contract` are the two exceptions: `/init` writes them **empty** (not a `<...>` placeholder — a
  genuinely blank cell), since neither is knowable at scaffold time; the founder fills them later
  to configure a product-reference row's resolver source.
- `enabled` defaults to `true` for every newly-written row.
- `target-path` is pre-filled with the matching registry row's `target-path` default; the
  founder edits it later to point at their real docs tree.
- `/init` writes or merges the row table and the header comment on every path, and **never** adds,
  edits, or removes the optional "Voice & format" section — that section is entirely founder-owned.
  The optional "Additional Jira project keys" section is likewise never written **autonomously**;
  the **only** exception is Step 4g's fresh-write offer, where `/init` may write the exact
  founder-supplied validated keys (no stub, no example, no `<...>` placeholder). A blank offer and
  every merge-path run leave it untouched.
- The optional "Reference roots" section is likewise never written **autonomously** by `/init` in
  this story — it is founder-authored, exactly like "Voice & format". A future story may add an
  init-time prompt for it; until then a founder wanting the four artifact-reference rows live adds
  the section by hand.

## Decline record convention

On a re-run merge (`/sdlc:init` Step 4g, existing-manifest path), a registry row the founder
declines to append is recorded with a comment line, so subsequent re-runs read it and skip
re-offering that type:

```markdown
<!-- declined: <type>[, <type>...] -->
```

One comment line may list multiple declined types, comma-separated. This line is the only record
of a decline — declining does not write (and never overwrites) a disabled row for that type.
