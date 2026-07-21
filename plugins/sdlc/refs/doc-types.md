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

| Column            | Meaning                                                                                                                                                                       | Allowed values                                                                                                                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `type`            | Stable doc-type identifier (kebab-case)                                                                                                                                       | e.g. `command-reference`, `how-to`, `tutorial`, `concept`, `changelog`, `adr`, `llms-txt`                                                                                                        |
| `quadrant`        | Diataxis quadrant                                                                                                                                                             | `tutorial` \| `how-to` \| `reference` \| `explanation` \| `meta` (`meta` is for cross-cutting artifacts — e.g. `llms.txt`, the ADR index — that do not sit in a single quadrant)                 |
| `trigger`         | The verb/moment(s) that regenerate this doc type; each token maps to a future `/sdlc:docs` mode                                                                               | one or more of `sync` \| `release` \| `seed` \| `audit` \| `distill`, **comma-separated with no spaces** (e.g. `seed,sync`); every token must be one of the five modes                           |
| `source-of-truth` | Where the content is derived from                                                                                                                                             | e.g. `command frontmatter + link to source`, `generated pages of all enabled public:yes manifest rows`, `merged stories since last tag`, `founder-authored`, `learnings corpus`, `accepted ADRs` |
| `generation-mode` | How much automation is allowed                                                                                                                                                | `auto` \| `draft-for-review` \| `manual-only`                                                                                                                                                    |
| `target-path`     | Default output path token (a placeholder the consumer manifest overrides)                                                                                                     | e.g. `docs/reference/commands/`, `docs/adr/`                                                                                                                                                     |
| `public`          | Whether the type is ever published to public docs                                                                                                                             | `yes` \| `no`                                                                                                                                                                                    |
| `applies-when`    | Condition gating whether the row is pre-filled into a consumer manifest by `/init`, AND — for the reference rows this story activation-gates — whether the row is live at all | `always`, or a condition string over the evaluation inputs below                                                                                                                                 |

## Doc-type families

Two families sit inside the `reference` quadrant, distinguished by how their `applies-when`
predicate resolves (the family itself is descriptive prose here, not a 9th schema column):

- **artifact-reference** — `command-reference`, `agent-reference`, `skill-reference`,
  `hooks-contract`. These document a repo's own Claude Code artifacts (commands, agents, skills,
  hooks) and activate on **presence of a configured `reference-roots` list** in the consumer
  manifest (`applies-when: reference-roots:present`) — a plain product repo that authors no such
  artifacts configures nothing and these four rows simply never activate.
- **product-reference** — `api-reference`, `schema-reference`, `config-reference`, `cli-reference`,
  `error-reference`. These document a repo's actual product surface (an HTTP API, a config schema,
  a CLI, an aggregated error-handling contract) and activate on a **declared contract or a
  configured source** (`applies-when: contract-or-source:<kind>` for `api`/`schema`/`config`, or
  `applies-when: source:present` for the configured-source-only `cli`/`error` pair).

`llms-txt` (the `meta` quadrant) is the only reference-family row that stays `applies-when: always`
— see the Registry self-check below. Narrative (`tutorial`/`how-to`/`concept`/`integration-guide`)
and release-mode (`changelog`/`release-notes`/`migration-guide`) rows are unaffected by either
family and remain `always`.

## `applies-when` condition grammar

`applies-when` is evaluated by `/init` (for manifest pre-fill) and by `/sdlc:docs` (for whether a
reference row is live at all) against three declared inputs:

1. The **repo-detect output contract** (`refs/repo-detect.md`) — the seven canonical fields:
   `language`, `framework`, `package_manager`, `test_runner`, `typecheck`, `runtime`,
   `commit_scopes`.
2. The repo's **declared dependency list** — the `dependencies` and `devDependencies` keys read
   from the repo's root `package.json`, the same source `refs/skills-map.yml`'s `dep:` conditions
   already evaluate against.
3. The consumer's **`.claude/project/docs-manifest.md`** — specifically its repo-level
   `reference-roots` list and its per-row `source:`/`contract:` fields (see
   `refs/docs-manifest-template.md`). This third input is what the four new/changed reference
   predicates below evaluate against; inputs 1–2 remain the sole inputs for `framework:`/
   `language:`/`dep:`.

Grammar operators:

- `always` — the row is always pre-filled/live. Narrative, release-mode, and `llms-txt` rows use
  this.
- `framework:<value>` — matches when `framework` (input 1) contains `<value>`.
- `language:<value>` — matches when `language` (input 1) contains `<value>`.
- `dep:<pkg>` — matches when `<pkg>` appears in the declared dependency list (input 2), same
  semantics as `refs/skills-map.yml`'s `dep:` condition.
- `reference-roots:present` — matches when the consumer manifest declares a non-empty repo-level
  `reference-roots` list (input 3). Gates the four artifact-reference rows.
- `contract-or-source:<kind>` — matches when a declared contract of `<kind>` (`openapi`, `schema`,
  or `config`) resolves at a conventional or manifest-configured path (input 3's `contract:`), **or**
  the row carries a manifest `source:` (input 3). Gates `api-reference`, `schema-reference`, and
  `config-reference`.
- `source:present` — matches when the row carries a manifest `source:` (input 3) — the configured-
  source-only gate for `cli-reference` and `error-reference` (no contract detection for either).

## Rows

| type                | quadrant    | trigger        | source-of-truth                                                                                                                                                                                                                                                                                          | generation-mode  | target-path                | public | applies-when                 |
| ------------------- | ----------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------- | ------ | ---------------------------- |
| `command-reference` | reference   | `sync`         | each configured `reference-roots` dir's `commands/**` frontmatter + link to source (transformed page: purpose/usage/tools from frontmatter plus a Source link — never the command's body; scoped by `reference-excludes`; see `refs/docs-pipeline.md` §3's source-resolver scan rung)                    | auto             | `docs/reference/commands/` | yes    | `reference-roots:present`    |
| `agent-reference`   | reference   | `sync`         | each configured `reference-roots` dir's `agents/**` definition frontmatter + link to source (transformed page: role/tools/triggers from frontmatter plus a Source link — never the agent's body; scoped by `reference-excludes`; see `refs/docs-pipeline.md` §3's source-resolver scan rung)             | auto             | `docs/reference/agents/`   | yes    | `reference-roots:present`    |
| `skill-reference`   | reference   | `sync`         | each configured `reference-roots` dir's `skills/**/SKILL.md` frontmatter, scoped by `reference-excludes` (see `refs/docs-pipeline.md` §3's source-resolver scan rung)                                                                                                                                    | auto             | `docs/reference/skills/`   | yes    | `reference-roots:present`    |
| `hooks-contract`    | reference   | `sync`         | each configured `reference-roots` dir's `hooks/hooks.json` plus referenced hook scripts, scoped by `reference-excludes` (see `refs/docs-pipeline.md` §3's source-resolver scan rung)                                                                                                                     | auto             | `docs/reference/hooks/`    | yes    | `reference-roots:present`    |
| `api-reference`     | reference   | `sync`         | a declared OpenAPI/Swagger contract at a conventional or manifest-configured path, generated from the contract's own structure (paths + methods) with a prominent Source link — never parsed from application source (see `refs/docs-pipeline.md` §3's Contract conventions)                             | auto             | `docs/reference/api/`      | yes    | `contract-or-source:openapi` |
| `schema-reference`  | reference   | `sync`         | a declared JSON-Schema/GraphQL-schema contract at a conventional or manifest-configured path, generated from the contract's own structure (properties) with a prominent Source link (see `refs/docs-pipeline.md` §3's Contract conventions)                                                              | auto             | `docs/reference/schema/`   | yes    | `contract-or-source:schema`  |
| `config-reference`  | reference   | `sync`         | family-resolved: a declared JSON-Schema/env-schema contract (product repos), OR the manifest's configured `source:`/`contract:` config-contract templates (artifact repos) — one registry row, resolved by the shared source resolver, never two rows (see `refs/docs-pipeline.md` §3's source resolver) | auto             | `docs/reference/config/`   | yes    | `contract-or-source:config`  |
| `cli-reference`     | reference   | `sync`         | the manifest's configured `source:` (path or `command:`) documenting the repo's CLI surface, emitted with a prominent Source link — configured-source-only, no invented CLI-arg parsing (see `refs/docs-pipeline.md` §3's Contract conventions)                                                          | auto             | `docs/reference/cli/`      | yes    | `source:present`             |
| `error-reference`   | reference   | `sync`         | real Error Handling sections aggregated per the manifest row's configured `source:` scan directive — a special aggregating type, not a lone file/command (see `refs/docs-pipeline.md` §3 step 9 for the exhaustive-scan requirement and the real-section-vs-stub test)                                   | auto             | `docs/reference/errors/`   | yes    | `source:present`             |
| `llms-txt`          | meta        | `sync`         | generated pages of all enabled public:yes manifest rows                                                                                                                                                                                                                                                  | auto             | `llms.txt`                 | yes    | `always`                     |
| `changelog`         | reference   | `release`      | merged stories since last tag                                                                                                                                                                                                                                                                            | draft-for-review | `docs/changelog/`          | yes    | `always`                     |
| `release-notes`     | explanation | `release`      | merged stories since last tag                                                                                                                                                                                                                                                                            | draft-for-review | `docs/release-notes/`      | yes    | `always`                     |
| `migration-guide`   | how-to      | `release`      | merged stories since last tag                                                                                                                                                                                                                                                                            | draft-for-review | `docs/migration-guides/`   | yes    | `always`                     |
| `tutorial`          | tutorial    | `seed`         | founder-authored                                                                                                                                                                                                                                                                                         | manual-only      | `docs/tutorials/`          | yes    | `always`                     |
| `how-to`            | how-to      | `seed,sync`    | founder-authored draft + learnings corpus                                                                                                                                                                                                                                                                | draft-for-review | `docs/how-to/`             | yes    | `always`                     |
| `integration-guide` | how-to      | `seed`         | founder-authored draft + learnings corpus                                                                                                                                                                                                                                                                | draft-for-review | `docs/integrations/`       | yes    | `always`                     |
| `concept`           | explanation | `seed`         | learnings corpus                                                                                                                                                                                                                                                                                         | draft-for-review | `docs/concepts/`           | yes    | `always`                     |
| `adr`               | meta        | `seed,distill` | accepted ADRs                                                                                                                                                                                                                                                                                            | draft-for-review | `docs/adr/`                | no     | `always`                     |

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
- **Every reference row is activation-gated; only `llms-txt` and the untouched narrative/release
  rows remain `always`.** The four artifact-reference rows (`command-reference`,
  `agent-reference`, `skill-reference`, `hooks-contract`) gate on `reference-roots:present`; the
  five product-reference rows gate on `contract-or-source:<kind>` (`api`/`schema`/`config`) or
  `source:present` (`cli`/`error`). `llms-txt` is the sole reference-family row that stays
  `always` — regenerated every run regardless of which other rows are active (see
  `refs/docs-pipeline.md` §8/§14's change-gate keying).
- **Reference-roots-scanned rows are `auto`.** `command-reference`, `agent-reference`,
  `skill-reference`, and `hooks-contract` each MUST have `generation-mode = auto` (deterministic
  frontmatter scan, no narrative synthesis).
- **Resolver-driven product-reference rows are `auto` too, but not frontmatter-driven.**
  `api-reference`, `schema-reference`, `config-reference`, `cli-reference`, and `error-reference`
  each MUST have `generation-mode = auto` — they are contract/source-driven, resolved by the
  shared source resolver of `refs/docs-pipeline.md` §3, and are **not** listed under the
  reference-roots-scanned set above (that set stays the four artifact rows only).
- **`llms-txt` is `auto`.** Deterministic aggregation of already-generated pages, no narrative
  synthesis.
- **Narrative rows are never `auto`.** `tutorial`, `how-to`, `concept`, `integration-guide`,
  `release-notes`, and `migration-guide` MUST each be `draft-for-review` or `manual-only`.
- **`llms-txt` source-of-truth string is singular.** The literal `source-of-truth` cell text for
  the `llms-txt` row (`generated pages of all enabled public:yes manifest rows`) is authored in
  exactly two places in this file — the registry row above and its "Allowed values" mirror in the
  Registry row schema table — kept in sync by the mirroring rule already stated there. Any other
  file that needs this fact (`refs/docs-pipeline.md` §8, `commands/docs.md`) references "the
  `llms-txt` row's `source-of-truth` cell in refs/doc-types.md" rather than restating the literal
  string, so there is only one string to update when its wording changes.
