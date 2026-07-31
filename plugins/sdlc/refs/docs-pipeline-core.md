# Docs pipeline — core (§§1–9)

**Core slice — read by every `/sdlc:docs` dispatch.** Shared resolve → diff → regen → draft →
founder-confirm → write → commit/PR protocol underlying every mode: the manifest gate (§1), the
two-phase dispatch split (§2), the deterministic regen algorithm (§3), voice/format resolution
(§4), the `source:` refresh convention (§5), no-op/change-gate semantics (§6), `sync`'s own
branch/PR naming + control flow (§7), the `llms.txt` format decision (§8), and cross-references
(§9). Split from the former single monolithic reference file at NA-79 — section numbers are
**preserved unchanged** across the split, so an existing "§N" reference still resolves to the same
content, now living in a mode-scoped file rather than one monolith. The other four mode-specific
slices are never read standalone — each is read together with this core slice:
`docs-pipeline-release.md` (§§10–14, `/sdlc:docs release`), `docs-pipeline-seed.md` (§§15–19,
`/sdlc:docs seed`), `docs-pipeline-audit.md` (§§20–24, `/sdlc:docs audit`), and
`docs-pipeline-postqa.md` (§§25–26, the post-QA inline-sync dispatch variant + the dual diff-source
selection rule that `sync`'s own merged-commit path below also depends on). The former monolith's
path now holds only a thin index naming all five slices — not read for content. Referenced by both
`agents/knowledge-engineer.md` and `commands/docs.md` so the contract lives in exactly one place
per mode. Neither file re-inlines this logic — both summarize and link back here. Mirrors
`refs/adr-pipeline.md`'s shape (copy the skeleton; do not abstract a shared ref between the two —
same "copy the shape, do not generalize" rule `doc-types.md` and Epic NA-50 both state).

## 1. Purpose + ownership note

This is the single-source pipeline for `/sdlc:docs`. All writes land under paths resolved from the
consumer repo's `.claude/project/docs-manifest.md` (row `target-path`s) and, where the manifest is
silent, `.claude/project/project-context.md`. In this SDLC repo itself, a plugin-authoring write
(touching `plugins/**`) stays within the `ai-enablement-engineer` write-scope — see the Active-guard
scope note in the agent's First steps.

### Manifest gate (shared by sync, release, seed, and audit)

**Every mode that reads the manifest** applies this identical gate at the **command layer**, before
any dispatch — defined once here; `commands/docs.md` points at it rather than re-deriving it.
Resolve
`.claude/project/docs-manifest.md` **checkout-independently** — never the working tree, so a stale
local checkout never skews which rows are active — but only **after** the base ref itself is
confirmed to resolve. A bare `git show origin/<BASE-BRANCH>:<path>` failure is otherwise ambiguous
between two very different causes: the path genuinely doesn't exist at that ref (manifest absent —
the intended silent no-op), or the **ref itself** doesn't resolve (a fresh/shallow CI clone that
hasn't fetched `<BASE-BRANCH>` yet, or `<BASE-BRANCH>` renamed/deleted on `origin`) — the latter
must **STOP**, never silently read as absent, or a fully opted-in repo carrying a real manifest gets
a silent no-op that reports success while generating nothing.

```bash
git fetch origin --quiet || STOP "git fetch failed"
git rev-parse --verify --quiet "origin/<BASE-BRANCH>^{commit}" >/dev/null \
  || STOP "cannot resolve origin/<BASE-BRANCH>"

git show "origin/<BASE-BRANCH>:.claude/project/docs-manifest.md" >/dev/null 2>&1
```

- **`git show` succeeds** → the manifest exists; proceed into the invoking mode's own steps.
- **`git show` fails** → now unambiguous, because the ref above already resolved — the failure means
  the **path** doesn't exist at that (known-good) ref, i.e. genuine manifest absence → **silent
  no-op**: no branch, no dispatch, no PR, no error, **no stdout**, exit 0 (AC5 for `sync`, AC6 for
  `release`). This is the zero-setup-cost guarantee for repos that declined the `/init` docs opt-in,
  deliberately distinct from a usage STOP (which does print a message). Do not dispatch
  `knowledge-engineer` in this case.

## 2. Two-phase dispatch (split across the confirmation boundary)

A dispatched subagent runs to completion and returns — it cannot pause for interactive human
input. So the founder-confirmation gate cannot live inside the `knowledge-engineer` dispatch; it
lives at the **command layer**, between two separate dispatches of the same agent. This is the
same split `refs/adr-pipeline.md` §2 and `/sdlc:analyze`'s scan-then-apply flow use.

**Phase 1 — compute & draft, writes nothing:**

1. Resolve `.claude/project/docs-manifest.md`. (The command layer already gated on its presence
   before dispatching — see §6 — so phase 1 always has a manifest to read.)
2. **Resolve the diff source and `REGEN_TREE_REF`.** The command layer resolves
   [`docs-pipeline-postqa.md` §26's selection rule](docs-pipeline-postqa.md#26-dual-diff-source--selection-rule)
   **before** dispatching and hands
   phase 1 exactly one of the following two shapes — phase 1 never re-runs the selection itself:
   - **`STORY_BRANCH` resolved** (the common case, including every post-QA dispatch — `docs-pipeline-postqa.md` §25) — the
     command layer passes `STORY_BRANCH` (`git fetch origin --quiet`, then
     `origin/feat/<STORY-KEY>` preferred, `origin/fix/<STORY-KEY>` fallback, per §7); phase 1 does
     **not** re-resolve it. `REGEN_TREE_REF` = `$STORY_BRANCH`.
   - **`STORY_BRANCH` absent — merged-commit source selected** (`docs-pipeline-postqa.md` §26, standalone `sync` only) — the
     command layer instead passes phase 1 **precomputed** `CHANGED_FILES` / `CHANGED_DIFF` (already
     derived from the merged commit(s)' `<sha>^..<sha>` range, or the union across matches, per
     `docs-pipeline-postqa.md` §26)
     and `REGEN_TREE_REF` = `origin/<BASE-BRANCH>` — post-merge, base HEAD already contains the
     landed commit(s), so it is both the tree the deterministic regen reads from (step 5) and the
     tree Phase 2 checks out from (step 8). `STORY_BRANCH` stays empty in this shape.
3. **`CHANGED_FILES` / `CHANGED_DIFF`.**
   - **Precomputed values were passed** (previous step, merged-commit shape) → use them
     **verbatim**; do **not** recompute — there is no `$STORY_BRANCH` to diff against.
   - **Otherwise** (the common `STORY_BRANCH`-present shape) → compute
     `CHANGED_FILES=$(git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH")` and
     `CHANGED_DIFF=$(git diff "origin/<BASE-BRANCH>...$STORY_BRANCH")` — both from the same
     three-dot range, against the **remote-tracking** base ref (see §7) — never the bare local
     `<BASE-BRANCH>`, whose local checkout may be stale relative to `origin`.
4. Resolve affected rows against the [source-of-truth map](#3-deterministic-regen-algorithm) — for
   each **enabled** manifest row whose registry `trigger` contains `sync`, determine whether it is
   affected per its keying kind (path / content / always).
5. For each affected `auto` row, produce the deterministic regen content (see §3), reading each
   file's current content from `REGEN_TREE_REF` (step 2 — `git show $REGEN_TREE_REF:<path>` per
   file, no full checkout needed in phase 1). `llms-txt` regenerates every run (AC4).
6. For each affected `how-to` row, draft a refresh of the how-to page(s) whose `source:`
   frontmatter intersects `CHANGED_FILES` (see §5), using the `writing-docs` skill.
7. Return to the command layer: the deterministic regen summary + content, the `llms.txt` content,
   and the narrative how-to drafts. **Nothing is written to disk in phase 1.**

**Founder-confirmation gate (command layer, NOT the agent — see §2's opening paragraph and
`commands/docs.md`).**

- Present the deterministic regen summary (informational — auto rows are not gated) and each
  narrative how-to draft (gated). The founder may accept/edit/reject each narrative draft.
- The gate is **skipped** when there are zero narrative drafts — the run proceeds straight to
  phase 2.

**Phase 2 — write confirmed, fresh dispatch:**

Phase 2 is a fresh subagent dispatch with no visibility into phase 1's return or the gate that ran
in between — the command MUST pass it the deterministic content **and** the founder-confirmed
narrative drafts **verbatim** (including any founder edits), inline in the dispatch prompt or via
session temp-dir files passed by path (per `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`, the same
pattern `refs/adr-pipeline.md` §2 uses). Phase 2 writes what the founder saw; it never re-drafts.

8. Check out a branch cut from **`REGEN_TREE_REF`** (step 2 — the **story branch head**
   `$STORY_BRANCH` when present, or `origin/<BASE-BRANCH>` on the merged-commit path; never the
   bare local `<BASE-BRANCH>` — see §7) — the tree must contain the changed source the regen read.
9. Write the deterministic regen content, the regenerated `llms.txt`, and the founder-confirmed
   narrative drafts, each under its manifest-resolved `target-path`.
10. If `git status --porcelain` on the written target paths is **empty** (deterministic output was
    byte-identical to what's already committed, and no narrative draft was confirmed) → no commit,
    no PR, exit cleanly (AC6). Otherwise commit via `conventional-commit`, push, and open or update
    the sync PR (see §7).

## 3. Deterministic regen algorithm

> **Activation note.** Every reference row (`refs/doc-types.md`'s artifact-reference and
> product-reference families) is activation-gated per that registry's `applies-when` — resolved
> against the consumer's own `.claude/project/docs-manifest.md` (repo-level `reference-roots`/
> `reference-excludes`, and per-row `source:`/`contract:`; see `refs/docs-manifest-template.md`).
> An inactive row is simply skipped by the resolver below (rung 4) — this section never hardcodes
> which directories a consumer documents; that is entirely manifest-declared.

For each **enabled** manifest row whose registry `trigger` contains `sync`, look up its registry
row in `refs/doc-types.md`, confirm it is **activated** per its `applies-when` predicate, then
resolve whether it is **affected** this run and where its content comes from via the shared
**source resolver** below.

### Source resolver

Applied per enabled + activated row, the resolver is an ordered ladder — a row is generated by the
**first** rung that produces a source, never more than one:

```text
resolve(row):
  1. contract  — if row.family == product-reference and row.type ∈ {api, config, schema}:
                 if row.contract is explicitly configured in the manifest it MUST resolve and
                 parse — a missing OR malformed configured contract → FAIL LOUD at the confirm
                 gate (surface the bad path to the founder); never fall through, never emit an
                 empty page. Otherwise look for the conventional contract path for that kind (see
                 Contract conventions below). If a contract is found → generate from it, emit a
                 "Source:" link to the contract file. STOP. If NO `contract:` is configured and
                 the conventional path is merely absent → fall through to rung 2 (an absent
                 conventional contract is not an error).
  2. source    — if row carries a manifest `source:` (path, glob/scan directive, or `command:`):
                 read/execute it, applying `reference-excludes` to any glob/scan match set;
                 generate from its output, emit a "Source:" link. STOP. (`cli`/`error` reach the
                 resolver only through this rung; `error-reference`'s source is an aggregating
                 scan directive — see the guards below.)
  3. scan      — if row.family == artifact-reference and the manifest's repo-level
                 `reference-roots` is non-empty: each declared root MUST exist — a
                 declared-but-missing root → FAIL LOUD at the confirm gate (surface the bad root);
                 never scan-as-empty (that would delete previously-generated artifact pages and
                 break the always-present guarantee). Walk each existing root for the type's
                 artifact files (`commands/**`, `agents/**`, `skills/**/SKILL.md`,
                 `hooks/hooks.json`), minus `reference-excludes`; transform each (frontmatter +
                 Source link, per the NA-64 transform-not-mirror rule — never copy the body). STOP.
  4. skip      — no contract, no source, no roots → generate NOTHING for this row. No page, no
                 empty stub, no `llms.txt` entry. This is the intended inactive-row case (no
                 `reference-roots`/no `source`/no `contract` configured), distinct from a
                 declared-but-missing root/contract, which FAILs LOUD instead.
```

**Idempotence:** each rung's output is a pure function of resolved source bytes + a fixed template

- a fixed Source-path string. Re-running against an unchanged contract/source/root set yields
  byte-identical pages.

**Change-gate keying** (drives `sync`'s regenerate-vs-skip decision, restated per row below):

- **path-keyed** — a row whose resolved source is a concrete file path (a contract file, a
  path-valued `source:`, or a file under a `reference-roots` entry) is affected only when that
  path intersects `CHANGED_FILES`/`CHANGED_DIFF`.
- **content/always-keyed** — a row whose resolved source has no path to intersect (any
  `command:`-prefixed `source:`, the `error-reference` aggregating scan, and `llms-txt`, which
  keeps its own `always` keying independent of source-intersection) regenerates on **every**
  `sync`, so it can never silently go stale.

| Doc-type | `generation-mode` | Keying | Affected when… |
| --- | --- | --- | --- |
| `command-reference` | auto | path | activated (`reference-roots:present`) and `CHANGED_FILES` contains a `commands/**` file under a declared root |
| `agent-reference` | auto | path | activated and `CHANGED_FILES` contains an `agents/**` file under a declared root |
| `skill-reference` | auto | path | activated and `CHANGED_FILES` contains a `skills/**/SKILL.md` file under a declared root |
| `hooks-contract` | auto | content | activated and a `hooks/hooks.json` (or referenced hook script) under a declared root has hunks in `CHANGED_DIFF` |
| `api-reference` | auto | path | activated (contract or configured `source:` resolves) and the resolved contract/source path is in `CHANGED_FILES` |
| `schema-reference` | auto | path | activated and the resolved contract/source path is in `CHANGED_FILES` |
| `config-reference` | auto | path | activated and the resolved contract/source path (or template glob match) is in `CHANGED_FILES` |
| `cli-reference` | auto | path or always | activated; path-keyed when `source:` is a path, always-keyed when `source:` is `command:`-prefixed |
| `error-reference` | auto | content/always | activated; the aggregating scan is content/always-keyed (see the guards below) |
| `llms-txt` | auto | always | **every run** (AC4) |
| `how-to` | draft-for-review | path | `CHANGED_FILES` intersects an existing how-to page's `source:` frontmatter glob-list (see §5) |

For each affected row, regenerate its reference-doc set **deterministically** into the row's
manifest `target-path` — this is a prose algorithm executed inline by the dispatched agent, not a
committed script (matches the ADR index-regen algorithm in `refs/adr-pipeline.md` §10 and the
plugin's "instructions not code" style). **Idempotent**: re-running with no source change yields
byte-identical output.

### Contract conventions (product-reference detection)

The resolver's rung-1 contract lookup uses a conventional path per kind, overridable by a row's
manifest `contract:` value. No framework-specific route parsing — contract files only, and the
generator never parses application source to synthesize a contract.

| type | contract kind | conventional paths (first match wins) |
| --- | --- | --- |
| `api-reference` | OpenAPI / Swagger | `openapi.json`, `openapi.yaml`, `openapi.yml`, `swagger.json`, `docs/openapi.*` |
| `schema-reference` | JSON-Schema / GraphQL | `schema.json`, `schema.graphql`, `*.schema.json`, `docs/schema.*` |
| `config-reference` | JSON-Schema / env | `config.schema.json`, `.env.schema`, `.env.example` (env-schema); artifact repos: configured `source:`/templates |

`cli-reference` and `error-reference` have **no** conventional contract — they resolve only via a
manifest `source:` (rung 2); no invented CLI-arg or error parsers. When rung 1 finds a contract,
the page is generated from the contract's own structure (paths + methods for OpenAPI; properties
for JSON-Schema) with a prominent **Source:** link to the contract file.

1. **`command-reference`** — for each `commands/**` file under a declared `reference-roots` entry,
   parse **frontmatter only** — the body is the command's runtime dispatch prompt (routinely tens
   of KB of directives to the agent that runs it), not reader-facing prose, and is **never** copied
   into the generated page. Emit one reference page per command, every page the same fixed shape:
   - **H1** — the command's invocation name (e.g. `/sdlc:docs`), derived deterministically from the
     source file's path/slug under its root's `commands/` directory — never typed by hand.
   - **One-line purpose** — the `description:` frontmatter value, run through the Description/title
     sanitization rule below.
   - **Usage** — the `argument-hint:` frontmatter value, when the source carries one; the line is
     **omitted entirely** (not rendered empty) when the source has no `argument-hint`.
   - **Tools** — the `allowed-tools:` (or equivalent tools-surface) frontmatter value, when present;
     omitted when absent.
   - **Source** — a prominent link to the repo-relative source path (e.g.
     `commands/deploy.md` under a declared `reference-roots` entry), with a one-line note that the source file is authoritative for
     full behavior (modes, gates, control flow) — the page never paraphrases or summarizes that
     behavior itself.

   Runtime-only frontmatter (`model`, a raw `allowed-tools` dump beyond the surfaced list, internal
   dispatch signals) is stripped from the rendered page — only the reader-relevant fields above are
   surfaced. If the source states a short, cheaply and deterministically extractable modes/args list
   in its own frontmatter, include it under Usage; otherwise defer to the Source link rather than
   summarizing the body's prose. Every field above is a deterministic frontmatter read plus a fixed
   template plus a fixed source-path string — no byte of the source's body is ever read for page
   content, so the page is idempotent (re-running with no frontmatter change yields byte-identical
   output) without needing to re-derive prose from a multi-KB runtime prompt.

2. **`agent-reference`** — same fixed-shape, frontmatter-only, link-to-source treatment, one page
   per `agents/**` file under a declared `reference-roots` entry:
   - **H1** — the agent name (`name:` frontmatter).
   - **Role/purpose** — the `description:` frontmatter value, sanitized identically.
   - **Tools** — the `tools:` frontmatter value, when present.
   - **Triggers** — when-invoked/trigger information, only when the source states it as its own
     frontmatter field (e.g. a dedicated `triggers:`/`invoked-by:` key); omitted when the source's
     frontmatter is silent on this — never inferred from prose inside `description:` or from the
     agent's body playbook.
   - **Source** — the same prominent Source link and authoritative-body caveat as `command-reference`.

   Same rule: frontmatter + a fixed template + the source-path link, never the body, and never a
   prose summary of it.

3. **`skill-reference`** — same, one page per `skills/**/SKILL.md`'s frontmatter (`name`,
   `description`) under a declared `reference-roots` entry.
4. **`hooks-contract`** — parse every declared root's own `hooks/hooks.json`, plus any script
   either references; emit a single reference page per root describing the hook contract it
   installs (trigger, matcher, command).
5. **`api-reference`** — resolved per the Contract conventions above (rung 1) or a configured
   `source:` (rung 2). Generate a single reference page from the contract's paths + methods (or the
   configured source's own structure), with a prominent Source link — the page never paraphrases
   application source, only the contract/source itself.
6. **`schema-reference`** — same treatment as `api-reference`, generated from the JSON-Schema/
   GraphQL contract's properties.
7. **`config-reference`** — **family-resolved**, one registry row, resolved by the shared source
   resolver: a product repo resolves it from a JSON-Schema/env-schema contract (rung 1); an
   artifact repo (one that ships its own plugin/config-contract templates) resolves it from a
   configured `source:`/`contract:` pointing at those templates (rung 2). Either way, emit a single
   reference page enumerating the config surface **a consumer of that contract/template set must
   provide**, described generically from the resolved source — never a repo's own filled-in
   config values. **A derived description captures the entry's full first paragraph** — every line
   up to the first blank line — **not just the first physical source line** (see the "Description/
   title sanitization" rule below; a paragraph that wraps across lines is one logical description,
   and truncating at the first `\n` silently drops the rest of the sentence).
8. **`cli-reference`** — configured-`source:`-only (rung 2); no conventional contract, no invented
   CLI-arg parsing. Generate a single reference page from the configured source's own output
   (a file's content, or a `command:`'s captured stdout), with a prominent Source link/note.
9. **`error-reference`** — **special aggregating type**: reached via rung 2, but its `source:` is
   an aggregating **scan directive**, not a lone file/command, and it retains all of the following
   guards (a family-resolved plain single-source reading that drops them is a defect):
   - **Exhaustive cross-root scan** — every file under `commands/**`, `agents/**`, and `refs/**` in
     **every** root the configured scan directive names (scoped by `reference-roots`/
     `reference-excludes`) — do not hand-curate a subset; a partial scan silently drops real
     sections, the defect class this rule exists to close.
   - **Case-insensitive section match** — `## Error Handling` and `## Error handling` both match;
     do not key the scan on one exact casing.
   - **A section is "real"** when it enumerates concrete scenario/behaviour rows — a table or list
     mapping a condition to a handling behaviour (e.g. a `| Scenario | Behaviour | … |` table).
     Aggregate its rows.
   - **A section is a stub or a deferral, not a source, and is excluded from aggregation**: a
     template placeholder with no rows, or a section whose only content points at another file's
     canonical Error Handling table (e.g. "mirrors the spec's Error Handling section", "see X's
     Error Handling table") without listing any row of its own. A deferring section contributes
     nothing to aggregation itself — its rows are already captured wherever they're canonically
     defined, and duplicating them under the deferring file's name would misattribute the row's
     source.
10. **`llms-txt`** — see §8's format; regenerated every run regardless of whether any other row was
    affected (AC4). Every derived `title`/`description` is sanitized per the rule below before it
    is emitted.
11. **`how-to`** — NOT part of this deterministic step; affected how-to pages are drafted (not
    auto-written) per §5/§2 step 6, and only written after founder confirmation.

Regeneration for each `auto` row overwrites only the pages derived from files it found affected —
it never touches an unaffected row's pages, and it never touches `how-to` pages (draft-for-review,
gated).

### Description/title sanitization + frontmatter escaping (hard rule — every dispatch, regardless of which skills are loaded)

Steps 1–3 and 7 above copy a `description` (or a derived `title`) verbatim from a source file's own
frontmatter into generated output — `command-reference` and `agent-reference` source theirs
exclusively from frontmatter (never the body, per steps 1–2 above); `config-reference`'s derived
title may instead come from a source file's body first paragraph (step 7); `skill-reference` sources
from `SKILL.md` frontmatter; and `llms-txt` entries are derived from any of those pages' own
frontmatter. Three rules apply to every such copy, enforced by **this deterministic regen algorithm
itself** — never left to `writing-docs`'s Self-Review checklist, because that skill is not always
loaded when this algorithm runs: **`audit` never loads `writing-docs`** at all (see
`agents/knowledge-engineer.md`'s skill-loading table), and even on a `sync`/`release`/`seed` dispatch
that does load it for an unrelated narrative draft, this regen is deterministic copying, not
authoring — it never routes the copied text through that skill's checklist.

1. **No em-dash in a derived `title`/`description`.** A source `description:` (command, agent, or
   skill frontmatter) legitimately contains an em-dash (U+2014, surrounded by a space on each side)
   as ordinary prose punctuation. §8's `llms.txt` format parses each entry positionally as
   `title`, then a space, an em-dash, and a space, then `description`, then the same delimiter again,
   then `link` — splitting on that space-em-dash-space sequence; a description that itself contains
   one yields extra delimiters and the split is ambiguous or wrong — the same collision
   `writing-docs`'s own craft rules warn a founder against when authoring narrative frontmatter by
   hand. Before emitting a derived `title:`/`description:` into **(a)** a generated reference page's
   own frontmatter **or (b)** an `llms.txt` entry, replace every em-dash in the copied text with a
   colon, semicolon, comma, or plain hyphen — never simply strip it, which can fuse two clauses into
   one unreadable run-on.
2. **Full first paragraph, not first physical line.** Applies wherever a derived description is
   sourced from a multi-line intro paragraph (see step 7's `config-reference` note above): capture
   every line up to the first blank line, not just the first line of source text.
3. **YAML single-quote escaping.** A generated page's frontmatter block MUST use correct YAML
   single-quote escaping for any copied text placed inside a `'...'` scalar: a literal apostrophe in
   the source text is doubled **exactly once** (`manager's` → `'manager''s'`), never doubled twice or
   more (`manager''''s` is a corruption of the escaping, not an intensified form of it — it renders
   as `manager''s`, two literal apostrophes, when the source had one). Before writing, verify the
   emitted apostrophe-doubling count matches the source's apostrophe count.

## 4. Voice/format resolution

Narrative drafting (the `how-to` refresh drafts) resolves voice and output format via
`writing-docs`'s chain, never hardcoded: `.claude/project/docs-manifest.md` "Voice & format"
section → `.claude/project/project-context.md` → a stated plain-Markdown, neutral-voice default
when neither is present or silent on a point. See `skills/writing-docs/SKILL.md`
"Voice, Craft, and Output Format" for the full resolution rule and the craft rules that apply
regardless of which source resolves it.

## 5. `source:` refresh convention

Restated here verbatim (normative source: `docs/superpowers/specs/NA-52.md` "`source:` frontmatter
convention") so pipeline readers see it alongside the drafting flow, and so it is not duplicated
inconsistently between this ref and the how-to template it governs:

- **Key name:** `source` (a top-level YAML frontmatter key on a how-to page).
- **Value:** a YAML list of repo-root-relative **glob** strings identifying the source files whose
  change should trigger a refresh draft of this page.
- **Match semantics:** a how-to page is **affected** iff at least one entry in its `source:` list
  matches at least one path in `CHANGED_FILES` under standard glob semantics (`*` within a path
  segment, `**` across segments). Matching is against the name-only changed-file set — it is a
  path-keyed row (see §3's table).
- **Absent key:** a how-to page with **no** `source:` frontmatter is **never** auto-refreshed by
  `sync`. This is the deliberate opt-in boundary — authoring/opting a page in is a founder action
  (add `source:`), not something `sync` infers.
- The template that emits this key at authoring time lives in
  `skills/writing-docs/SKILL.md`'s how-to structure template — see that file for the
  exact emitted shape (a one-line inline comment plus the `source:` glob list).

## 6. No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** See [§1's Manifest gate](#manifest-gate-shared-by-sync-release-seed-and-audit)
  — the command layer never dispatches `knowledge-engineer` when that gate finds the manifest
  genuinely absent, distinct from the STOP the same gate raises first if `origin/<BASE-BRANCH>`
  itself won't resolve. Not something phase 1 checks — phase 1 is never invoked in this case.
- **Story-branch-missing → merged-commit source, never a silent success.** If neither
  `origin/feat/<STORY-KEY>` nor `origin/fix/<STORY-KEY>` exists, standalone `sync` selects the
  **merged-commit** diff source ([`docs-pipeline-postqa.md` §26](docs-pipeline-postqa.md#26-dual-diff-source--selection-rule)) — it locates the
  landed commit(s) for `<STORY-KEY>` on `origin/<BASE-BRANCH>` and diffs the merged range. A genuine
  zero-match STOPs with an explicit error (`docs-pipeline-postqa.md` §26); it is never a silent clean exit that reads as "docs
  already current." The post-QA phase (`docs-pipeline-postqa.md` §25) never hits this branch — its story branch is always
  present.
- **Commit/PR only on actual content change (AC6).** Phase 2 step 10 (§2) is the single point that
  decides this: an empty `git status --porcelain` on the written target paths means no commit, no
  PR — a clean, deterministic re-run is a no-op by construction.
- **`llms.txt` regenerated every run, committed only if changed (AC4 + AC6).** `llms-txt` is always
  affected (§3's table), so its content is always recomputed — but §2 step 10's change-gate still
  applies: if the recomputed content is byte-identical to what's committed, it contributes nothing
  to the `git status --porcelain` diff and is not part of the commit.

## 7. Branch / PR naming + control flow

| Item | Value |
| --- | --- |
| Branch | `docs/sync-<STORY-KEY>`, cut from `REGEN_TREE_REF` (§2 step 2) — the **story branch head** (`origin/feat/<STORY-KEY>`, fallback `origin/fix/<STORY-KEY>`) when present, or `origin/<BASE-BRANCH>` on the **merged-commit** path (`docs-pipeline-postqa.md` §26, story branch absent) — never a bare local branch. `REGEN_TREE_REF` carries the changed source the deterministic regen must read; branching off a tree missing those changes would regenerate stale content. |
| Commit | `docs(docs): sync <STORY-KEY> reference docs` (via `conventional-commit`) |
| PR title | `docs(docs): sync <STORY-KEY>` |
| PR base | `<BASE-BRANCH>` from project-context (never assume `main`) |
| Diff source | Two sources, selected per [`docs-pipeline-postqa.md` §26](docs-pipeline-postqa.md#26-dual-diff-source--selection-rule) — **story-branch-vs-base**: `CHANGED_FILES=$(git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH")` and `CHANGED_DIFF=$(git diff "origin/<BASE-BRANCH>...$STORY_BRANCH")`, both from the same three-dot range, against the **remote-tracking** base ref (checkout-independent — a stale local base never skews the diff), after `git fetch origin --quiet`; or **merged-commit** (`docs-pipeline-postqa.md` §26) when the story branch is absent. Standalone `sync` selects whichever §26 resolves; the post-QA phase (`docs-pipeline-postqa.md` §25) always passes story-branch-vs-base explicitly. |
| First-run PR | Create the branch, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`. |
| Re-run behaviour | **Open or update** (AC6): before creating, check whether `docs/sync-<STORY-KEY>` already exists on `origin` (`git rev-parse --verify origin/docs/sync-<STORY-KEY>` / `gh pr list --head docs/sync-<STORY-KEY>`). If it does → check it out, **`git reset --hard` onto the freshly regenerated state** (the branch content is fully derived, so a hard reset is safe and keeps history clean), then **`git push --force-with-lease`** to update the existing open PR — never open a duplicate PR. |
| Control-flow tail | Mirror `refs/adr-pipeline.md`'s §3a command-layer flow: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR — the manifest-absent silent no-op, a usage STOP, the merged-commit **zero-match STOP** (`docs-pipeline-postqa.md` §26 — the story branch is absent **and** no landed commit carries the key), or a clean "nothing changed" no-op — release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh`; only the manifest-absent path is silent. A **merged-commit match** (`docs-pipeline-postqa.md` §26) regenerates and proceeds to a PR like the story-branch-present case — it is no longer a release-without-a-PR path. |

## 8. llms.txt format (v1 decision)

`llms-txt` regenerates at the `llms-txt` row's manifest `target-path` (registry default `llms.txt`,
repo-root) deterministically on every run: an **index-only** file (no full-content `llms-full.txt`
in v1), grouping the generated pages of every enabled, `public: yes` manifest row by Diátaxis
quadrant, each entry a `title — one-line description — relative link` line derived from the
generated page's frontmatter. Idempotent, no narrative synthesis. This matches the `llms-txt` row's
`source-of-truth` cell in `refs/doc-types.md` — see that cell for the authoritative wording rather
than restating it here; `refs/doc-types.md`'s own Registry self-check section is what keeps that
cell's wording singular within that file.

> **Delimiter fragility — mitigated on two independent layers; still an Open Question for founder-typed
> prose that skips both.** This positional format splits each entry on a space, an em-dash, and a
> space, so a `title`/`description` whose own value legitimately contains an em-dash breaks the
> split.
>
> - **Machine-derived copies** — every `title`/`description` this format ultimately reads that was
>   copied verbatim from a source file's own frontmatter/body (`command-reference`,
>   `agent-reference`, `skill-reference`, `config-reference`) — are sanitized by §3's "Description/
>   title sanitization" rule, which is part of the deterministic regen algorithm itself and therefore
>   applies on **every** dispatch, including `audit` (which never loads `writing-docs`). This closes
>   the gap that let 30 generated pages ship an un-split `llms.txt` line: the audit dispatch that
>   regenerates these rows does not load `writing-docs`, so a rule that lived only in that skill's
>   checklist never applied to them.
> - **Founder-typed narrative prose** (`tutorial`/`how-to`/`concept`/`integration-guide`/etc.) —
>   NA-61's mitigation stands: `writing-docs`'s templates no longer model an em-dash in their
>   placeholder text, and both the skill's craft rules and its Self-Review checklist warn against one
>   in real filled copy — mitigated at authoring time, when `writing-docs` is loaded (every seed/how-
>   to/release-notes draft loads it per `agents/knowledge-engineer.md`'s skill-loading table).
>
> The format itself stays positional — a founder who ignores the craft-rule warning can still type an
> em-dash into narrative frontmatter that reaches `llms.txt` unfiltered by the authoring-time
> checklist, and this ref does not add a second sanitization pass over founder-confirmed narrative
> content (§2's phase 2 rule — "Phase 2 writes what the founder saw; it never re-drafts" — forbids
> re-deriving it at write time). Robustly closing this for every path would mean changing
> this v1 format (e.g. a structured/escaped delimiter, or per-field length-prefixing) — out of scope
> here; deferred as a follow-up.

## 9. Cross-reference

The registry (`refs/doc-types.md`) and the manifest template (`refs/docs-manifest-template.md`)
are read, not owned, by this pipeline — `sync` never edits either. The `writing-docs` skill
(`skills/writing-docs/SKILL.md`) owns the how-to structure template (including the
`source:` frontmatter emission, §5 above) and the voice/format resolution chain (§4 above) — this
ref restates the pieces `sync` depends on but does not re-inline the full skill.
