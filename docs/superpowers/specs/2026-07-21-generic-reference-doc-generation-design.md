# Generic, activation-gated reference-doc generation for `/sdlc:docs`

**Status:** Design (approved for planning)
**Date:** 2026-07-21
**Owner area:** sdlc plugin — `plugins/sdlc/refs/docs-pipeline.md`, `plugins/sdlc/refs/doc-types.md`, docs-manifest schema

## Problem

`/sdlc:docs`'s reference-doc generation was built around **this repo's** shape — a repo that authors
the sdlc & gtm plugins and dogfoods them. Recent changes hard-coded nightshift specifics
(`plugins/{sdlc,gtm}/**`, the `gtm` template, nx-mirror exclusions) into the **shipped** plugin
spec, and the reference doc-types (`command-reference`, `agent-reference`, `skill-reference`,
`hooks-contract`) are `applies-when: always` — which silently assumes every consumer authors Claude
Code artifacts.

The sdlc plugin's primary audience is **product builders** (SaaS/app teams), not artifact authors.
For them the Claude-Code-artifact reference rows have nothing to scan and produce empty docs, while
the reference docs they actually want — their product's **API / CLI / config / schema / error**
surface — aren't generated at all.

## Goals

1. The shipped plugin contains **zero** nightshift-specific strings. Repo-agnostic.
2. Reference doc-types are **activation-gated** — a type generates only when the repo actually has
   what it documents. Nothing is `always`.
3. Product repos get **product-reference** doc-types (api/cli/config/schema/error), sourced from
   declared contracts where they exist, else consumer-configured sources.
4. Nightshift reproduces its current reference-docs scope entirely from **its own** manifest.

## Non-goals

- No bespoke per-framework source parsing (no Hono/Express/FastAPI route walkers). Contracts only.
- No change to narrative rows (tutorial/how-to/concept/integration-guide) — they are
  founder-authored and already written from the plugin-user perspective.
- Not redesigning `llms-txt` (it indexes whatever generated; stays always-on).

## The model

### Activation

A reference row generates iff **both**:

- it is present + `enabled` in the consumer's `.claude/project/docs-manifest.md` (existing gate), and
- its `applies-when` condition holds against detected repo signals (existing registry column, now
  actually enforced for these rows instead of `always`).

Two families, distinguished only by how they activate and source:

- **Artifact-reference** — `command-reference`, `agent-reference`, `skill-reference`,
  `hooks-contract`. Activates when the repo authors that artifact: presence of the configured
  **reference-roots** containing `commands/` / `agents/` / `skills/**/SKILL.md` / `hooks/`.
- **Product-reference** — `api-reference`, `cli-reference`, `config-reference`, `schema-reference`,
  `error-reference`. Activates when a matching contract or configured source resolves (below).

### Source resolver (one shared mechanism)

For each activated row, resolve content in order:

1. **Declared contract** — a known standard artifact for the type, at a conventional path or a
   manifest-configured `contract:` path. Standards used:
   - `api-reference` ← OpenAPI/Swagger (`openapi.{json,yaml}`, `swagger.{json,yaml}`)
   - `config-reference` ← JSON Schema or env schema (`*.schema.json`, `.env.example`) **for a
     product repo**; **for an artifact repo**, the plugin config-contract templates the repo ships
     (resolved via configured source / convention — see "config-reference is family-resolved")
   - `schema-reference` ← JSON Schema / GraphQL SDL / declared DB schema
2. **Configured source** — the manifest names a `source:` path or command for the row.
3. **Convention scan** — artifact-reference only: the reference-roots scan, emitting the
   frontmatter+link transform (already built) for each command/agent/skill; hooks from
   `hooks/hooks.json` under the roots.
4. **Skip** — none resolved ⇒ the row is inactive this run (no empty page).

`cli-reference` and `error-reference` are **configured-source-only** (steps 2 → 4): no universal
contract standard exists, so the consumer points them at a source; no detection is invented.

### `config-reference` is family-resolved (single row)

One `config-reference` row serves both families; the resolver disambiguates by what's present:

- **Product repo** → a JSON/env schema contract (step 1) or a configured source (step 2): documents
  the product's configuration surface.
- **Artifact repo** (e.g. nightshift) → the plugin **config-contract templates** the repo ships,
  supplied via the manifest's configured `source:` (step 2) — e.g. nightshift points it at
  `plugins/{sdlc,gtm}/refs/*-template.md`. Never this repo's own filled-in `.claude/project/*`
  values.

## Config schema (docs-manifest — all optional, safe defaults)

- `reference-roots` (glob list) — where artifact-reference scans. **Default:** conventional Claude
  Code locations (`commands/`, `agents/`, `skills/**/SKILL.md`, `hooks/hooks.json`,
  `.claude/settings*.json`).
- `reference-excludes` (glob list) — trees to skip (generated/vendored/mirror dirs). **Default:**
  empty.
- Per-row `source:` (path or shell command) and `contract:` (path to an OpenAPI/JSON-schema file) —
  overrides for product-reference (and artifact `config-reference`) rows.

A plain product repo sets **nothing** and gets stack-detected behavior. Nightshift sets
`reference-roots: [plugins/sdlc, plugins/gtm]`, `reference-excludes: [<nx mirror dirs>, agents/,
skills/]`, and `config-reference.source: plugins/{sdlc,gtm}/refs/*-template.md`.

## Registry changes (`doc-types.md`)

- `command/agent/skill-reference`, `hooks-contract`: `applies-when` changes from `always` to the
  artifact-presence condition; `source-of-truth` cells become generic ("the repo's authored
  <artifact> under the configured reference-roots"), **no `plugins/{sdlc,gtm}` strings**.
- New rows: `api-reference`, `cli-reference`, `config-reference` (repurposed to family-resolved),
  `schema-reference`, `error-reference` — each with its contract/configured source-of-truth and
  `applies-when` = "contract or configured source resolves".
- `llms-txt`: unchanged (always; indexes whatever generated).

## Phases (all delivered)

**P1 — de-leak + activation foundation**
- Remove every `plugins/{sdlc,gtm}`/`gtm`/nx-mirror string from `docs-pipeline.md` + `doc-types.md`.
- Add `reference-roots`/`reference-excludes` + activation-gating for artifact rows (presence, not
  always). Add fields to `docs-manifest-template.md` and the manifest schema/self-check.
- Write nightshift's `.claude/project/docs-manifest.md` scope (reproduces #155 output exactly).

**P2 — product-reference framework + `api-reference`**
- Encode the source resolver (contract → configured → convention → skip) in `docs-pipeline.md` §3.
- Add the product-reference row schema. Ship `api-reference`: OpenAPI contract → transformed
  reference page + Source link; activates when a spec resolves.

**P3 — remaining product types**
- `cli-reference`, `error-reference` (configured-source-only), `config-reference`
  (family-resolved), `schema-reference` (JSON-schema/GraphQL contract, else configured). Each is a
  registry addition reusing P2's resolver.

## Nightshift migration

Nightshift's manifest carries the artifact scope; regenerate under the new model → supersedes the
current audit PR (#155). Deploy: cache-sync for local validation, a real sdlc plugin release for the
durable path (unchanged from current practice).

## Testing

- **Fixture A (product repo):** a mock repo with an `openapi.json` and no Claude Code artifacts →
  `api-reference` activates and generates; artifact rows stay inactive; output carries zero
  nightshift strings.
- **Fixture B (plain repo):** no contracts, no artifacts → all reference rows inactive, no empty
  pages, `llms-txt` still regenerates (indexing only narrative rows if any).
- **Fixture C (artifact repo):** mirrors nightshift's shape via manifest config →
  command/agent/skill/hooks + family-resolved config-reference generate, scoped by manifest roots.
- Existing `check-plugin-docs-format.sh` + idempotence (byte-identical re-run) checks apply per row.

## Rollout / risk

- Plugin spec is a published artifact: land via PR(s), deploy by cache-sync (local) then release.
- Backward-compat: a consumer with an existing manifest but no new fields gets convention defaults;
  the only behavior change is artifact rows no longer emitting empty pages when the repo has no such
  artifacts (an improvement).
