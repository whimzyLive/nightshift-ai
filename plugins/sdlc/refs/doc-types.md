# Doc-type registry for `/sdlc:init` and `/sdlc:docs`

This file is a **plugin-owned data registry** — a generic, stack-agnostic taxonomy of
documentation types keyed on the Diataxis framework (tutorials, how-to guides, reference,
explanation), plus a `meta` quadrant for cross-cutting artifacts. Consumer repos never edit this
file directly — they activate rows via their own `.claude/project/docs-manifest.md`, scaffolded
by `/sdlc:init` from `refs/docs-manifest-template.md`.

`/sdlc:docs` reads this registry for every row whose `trigger` names a live mode (see
`refs/docs-pipeline.md`). All five `/sdlc:docs` modes (`sync`/`release`/`seed`/`audit`/`distill`)
are now live; `seed` derives its valid type set from the `trigger` cells below at read time, and
`audit` partitions **every** activated row into its two drift tiers by `generation-mode` — so this
table, not the command, keys both. `audit` reads this registry read-only and touches no row.
`seed adr` and `distill` route to `refs/adr-pipeline.md` instead of the generic docs machinery.

Mirrors the documentary style of `refs/skills-map.yml` (a flat table registry). Do **not**
abstract a shared registry format between the two files — copy the shape, do not generalize.

## Registry row schema

Every row carries exactly these 8 columns, in this order:

| Column            | Meaning                                                                                         | Allowed values                                                                                                                                                                         |
| ----------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`            | Stable doc-type identifier (kebab-case)                                                         | e.g. `command-reference`, `how-to`, `tutorial`, `concept`, `changelog`, `adr`, `llms-txt`                                                                                              |
| `quadrant`        | Diataxis quadrant                                                                               | `tutorial` \| `how-to` \| `reference` \| `explanation` \| `meta` (`meta` is for cross-cutting artifacts — e.g. `llms.txt`, the ADR index — that do not sit in a single quadrant)       |
| `trigger`         | The verb/moment(s) that regenerate this doc type; each token maps to a future `/sdlc:docs` mode | one or more of `sync` \| `release` \| `seed` \| `audit` \| `distill`, **comma-separated with no spaces** (e.g. `seed,sync`); every token must be one of the five modes                 |
| `source-of-truth` | Where the content is derived from                                                               | e.g. `command frontmatter + body`, `generated pages of all enabled public:yes manifest rows`, `merged stories since last tag`, `founder-authored`, `learnings corpus`, `accepted ADRs` |
| `generation-mode` | How much automation is allowed                                                                  | `auto` \| `draft-for-review` \| `manual-only`                                                                                                                                          |
| `target-path`     | Default output path token (a placeholder the consumer manifest overrides)                       | e.g. `docs/reference/commands/`, `docs/adr/`                                                                                                                                           |
| `public`          | Whether the type is ever published to public docs                                               | `yes` \| `no`                                                                                                                                                                          |
| `applies-when`    | Stack condition gating whether the row is pre-filled into a consumer manifest by `/init`        | `always`, or a condition string over the evaluation inputs below                                                                                                                       |

## `applies-when` condition grammar

`applies-when` is evaluated by `/init` against two declared inputs:

1. The **repo-detect output contract** (`refs/repo-detect.md`) — the seven canonical fields:
   `language`, `framework`, `package_manager`, `test_runner`, `typecheck`, `runtime`,
   `commit_scopes`.
2. The repo's **declared dependency list** — the `dependencies` and `devDependencies` keys read
   from the repo's root `package.json`, the same source `refs/skills-map.yml`'s `dep:` conditions
   already evaluate against.

Grammar operators:

- `always` — the row is always pre-filled (all SDLC-artifact doc types below are stack-agnostic
  and use this).
- `framework:<value>` — matches when `framework` (input 1) contains `<value>`.
- `language:<value>` — matches when `language` (input 1) contains `<value>`.
- `dep:<pkg>` — matches when `<pkg>` appears in the declared dependency list (input 2), same
  semantics as `refs/skills-map.yml`'s `dep:` condition.

Every row currently ships with `applies-when = always` — the 15 mandatory doc types below are all
stack-agnostic. The grammar is specified now so a future stack-specific row (e.g. an
API-reference row gated on `framework:Hono`) slots in without a schema change.

## Rows

| type                | quadrant    | trigger        | source-of-truth                                         | generation-mode  | target-path                | public | applies-when |
| ------------------- | ----------- | -------------- | ------------------------------------------------------- | ---------------- | -------------------------- | ------ | ------------ |
| `command-reference` | reference   | `sync`         | command frontmatter + body                              | auto             | `docs/reference/commands/` | yes    | always       |
| `agent-reference`   | reference   | `sync`         | agent definition frontmatter + body                     | auto             | `docs/reference/agents/`   | yes    | always       |
| `skill-reference`   | reference   | `sync`         | skill `SKILL.md` frontmatter                            | auto             | `docs/reference/skills/`   | yes    | always       |
| `config-reference`  | reference   | `sync`         | `project-context.md` + config templates                 | auto             | `docs/reference/config/`   | yes    | always       |
| `hooks-contract`    | reference   | `sync`         | `settings.json` hooks schema + hook scripts             | auto             | `docs/reference/hooks/`    | yes    | always       |
| `error-reference`   | reference   | `sync`         | Error Handling tables across commands/agents/refs       | auto             | `docs/reference/errors/`   | yes    | always       |
| `llms-txt`          | meta        | `sync`         | generated pages of all enabled public:yes manifest rows | auto             | `llms.txt`                 | yes    | always       |
| `changelog`         | reference   | `release`      | merged stories since last tag                           | draft-for-review | `docs/changelog/`          | yes    | always       |
| `release-notes`     | explanation | `release`      | merged stories since last tag                           | draft-for-review | `docs/release-notes/`      | yes    | always       |
| `migration-guide`   | how-to      | `release`      | merged stories since last tag                           | draft-for-review | `docs/migration-guides/`   | yes    | always       |
| `tutorial`          | tutorial    | `seed`         | founder-authored                                        | manual-only      | `docs/tutorials/`          | yes    | always       |
| `how-to`            | how-to      | `seed,sync`    | founder-authored draft + learnings corpus               | draft-for-review | `docs/how-to/`             | yes    | always       |
| `integration-guide` | how-to      | `seed`         | founder-authored draft + learnings corpus               | draft-for-review | `docs/integrations/`       | yes    | always       |
| `concept`           | explanation | `seed`         | learnings corpus                                        | draft-for-review | `docs/concepts/`           | yes    | always       |
| `adr`               | meta        | `seed,distill` | accepted ADRs                                           | draft-for-review | `docs/adr/`                | no     | always       |

## Registry self-check

This is the **single canonical validation list** for the registry — the author before commit,
`/init` at scaffold time, and any later `/sdlc:docs` all validate against this section. The
Registry row schema table's "Allowed values" column above mirrors these same value sets by
design, for at-a-glance reference while filling a row — keep the two in sync whenever a mode or
value is added; this section remains the canonical source of truth that the schema table's column
merely echoes, and no section in this file, or in `refs/docs-manifest-template.md`, may diverge
from it.

- **No blank cells.** Every row populates all 8 schema columns.
- **Allowed value sets.** `generation-mode ∈ {auto, draft-for-review, manual-only}`;
  `public ∈ {yes, no}`; `quadrant ∈ {tutorial, how-to, reference, explanation, meta}`; and every
  comma-separated `trigger` token is among the five `/sdlc:docs` modes
  `{sync, release, seed, audit, distill}`.
- **ADR is internal.** The `adr` row MUST have `public = no` and `target-path = docs/adr/` — an
  internal doc type, never published to public docs.
- **Frontmatter-driven rows are `auto`.** `command-reference`, `agent-reference`,
  `skill-reference`, `config-reference`, `hooks-contract`, `error-reference`, and `llms-txt` each
  MUST have `generation-mode = auto` (deterministic, no narrative synthesis).
- **Narrative rows are never `auto`.** `tutorial`, `how-to`, `concept`, `integration-guide`,
  `release-notes`, and `migration-guide` MUST each be `draft-for-review` or `manual-only`.
- **`llms-txt` source-of-truth string is singular.** The literal `source-of-truth` cell text for
  the `llms-txt` row (`generated pages of all enabled public:yes manifest rows`) is authored in
  exactly two places in this file — the registry row above and its "Allowed values" mirror in the
  Registry row schema table — kept in sync by the mirroring rule already stated there. Any other
  file that needs this fact (`refs/docs-pipeline.md` §8, `commands/docs.md`) references "the
  `llms-txt` row's `source-of-truth` cell in refs/doc-types.md" rather than restating the literal
  string, so there is only one string to update when its wording changes.
