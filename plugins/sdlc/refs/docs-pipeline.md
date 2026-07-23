# Docs pipeline

Shared resolve → diff → regen → draft → founder-confirm → write → commit/PR protocol for
`/sdlc:docs sync` (§§2–8), `/sdlc:docs release` (§§10–14), `/sdlc:docs seed` (§§15–19), and
`/sdlc:docs audit` (§§20–24); the post-QA inline-sync wiring (the variant + dual diff source) lives
in §§25–26. Referenced by both `agents/knowledge-engineer.md` and `commands/docs.md` so the
contract lives in exactly one place. Neither file re-inlines this logic — both summarize and link
back here. Mirrors `refs/adr-pipeline.md`'s shape (copy the skeleton; do not abstract a shared ref
between the two — same "copy the shape, do not generalize" rule `doc-types.md` and Epic NA-50 both
state).

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
   [§26's selection rule](#26-dual-diff-source--selection-rule) **before** dispatching and hands
   phase 1 exactly one of the following two shapes — phase 1 never re-runs the selection itself:
   - **`STORY_BRANCH` resolved** (the common case, including every post-QA dispatch — §25) — the
     command layer passes `STORY_BRANCH` (`git fetch origin --quiet`, then
     `origin/feat/<STORY-KEY>` preferred, `origin/fix/<STORY-KEY>` fallback, per §7); phase 1 does
     **not** re-resolve it. `REGEN_TREE_REF` = `$STORY_BRANCH`.
   - **`STORY_BRANCH` absent — merged-commit source selected** (§26, standalone `sync` only) — the
     command layer instead passes phase 1 **precomputed** `CHANGED_FILES` / `CHANGED_DIFF` (already
     derived from the merged commit(s)' `<sha>^..<sha>` range, or the union across matches, per §26)
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

| Doc-type            | `generation-mode` | Keying         | Affected when…                                                                                                    |
| ------------------- | ----------------- | -------------- | ----------------------------------------------------------------------------------------------------------------- |
| `command-reference` | auto              | path           | activated (`reference-roots:present`) and `CHANGED_FILES` contains a `commands/**` file under a declared root     |
| `agent-reference`   | auto              | path           | activated and `CHANGED_FILES` contains an `agents/**` file under a declared root                                  |
| `skill-reference`   | auto              | path           | activated and `CHANGED_FILES` contains a `skills/**/SKILL.md` file under a declared root                          |
| `hooks-contract`    | auto              | content        | activated and a `hooks/hooks.json` (or referenced hook script) under a declared root has hunks in `CHANGED_DIFF`  |
| `api-reference`     | auto              | path           | activated (contract or configured `source:` resolves) and the resolved contract/source path is in `CHANGED_FILES` |
| `schema-reference`  | auto              | path           | activated and the resolved contract/source path is in `CHANGED_FILES`                                             |
| `config-reference`  | auto              | path           | activated and the resolved contract/source path (or template glob match) is in `CHANGED_FILES`                    |
| `cli-reference`     | auto              | path or always | activated; path-keyed when `source:` is a path, always-keyed when `source:` is `command:`-prefixed                |
| `error-reference`   | auto              | content/always | activated; the aggregating scan is content/always-keyed (see the guards below)                                    |
| `llms-txt`          | auto              | always         | **every run** (AC4)                                                                                               |
| `how-to`            | draft-for-review  | path           | `CHANGED_FILES` intersects an existing how-to page's `source:` frontmatter glob-list (see §5)                     |

For each affected row, regenerate its reference-doc set **deterministically** into the row's
manifest `target-path` — this is a prose algorithm executed inline by the dispatched agent, not a
committed script (matches the ADR index-regen algorithm in `refs/adr-pipeline.md` §10 and the
plugin's "instructions not code" style). **Idempotent**: re-running with no source change yields
byte-identical output.

### Contract conventions (product-reference detection)

The resolver's rung-1 contract lookup uses a conventional path per kind, overridable by a row's
manifest `contract:` value. No framework-specific route parsing — contract files only, and the
generator never parses application source to synthesize a contract.

| type               | contract kind         | conventional paths (first match wins)                                                                            |
| ------------------ | --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `api-reference`    | OpenAPI / Swagger     | `openapi.json`, `openapi.yaml`, `openapi.yml`, `swagger.json`, `docs/openapi.*`                                  |
| `schema-reference` | JSON-Schema / GraphQL | `schema.json`, `schema.graphql`, `*.schema.json`, `docs/schema.*`                                                |
| `config-reference` | JSON-Schema / env     | `config.schema.json`, `.env.schema`, `.env.example` (env-schema); artifact repos: configured `source:`/templates |

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
  **merged-commit** diff source ([§26](#26-dual-diff-source--selection-rule)) — it locates the
  landed commit(s) for `<STORY-KEY>` on `origin/<BASE-BRANCH>` and diffs the merged range. A genuine
  zero-match STOPs with an explicit error (§26); it is never a silent clean exit that reads as "docs
  already current." The post-QA phase (§25) never hits this branch — its story branch is always
  present.
- **Commit/PR only on actual content change (AC6).** Phase 2 step 10 (§2) is the single point that
  decides this: an empty `git status --porcelain` on the written target paths means no commit, no
  PR — a clean, deterministic re-run is a no-op by construction.
- **`llms.txt` regenerated every run, committed only if changed (AC4 + AC6).** `llms-txt` is always
  affected (§3's table), so its content is always recomputed — but §2 step 10's change-gate still
  applies: if the recomputed content is byte-identical to what's committed, it contributes nothing
  to the `git status --porcelain` diff and is not part of the commit.

## 7. Branch / PR naming + control flow

| Item              | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branch            | `docs/sync-<STORY-KEY>`, cut from `REGEN_TREE_REF` (§2 step 2) — the **story branch head** (`origin/feat/<STORY-KEY>`, fallback `origin/fix/<STORY-KEY>`) when present, or `origin/<BASE-BRANCH>` on the **merged-commit** path (§26, story branch absent) — never a bare local branch. `REGEN_TREE_REF` carries the changed source the deterministic regen must read; branching off a tree missing those changes would regenerate stale content.                                                                                                                                                                                                                                                                                              |
| Commit            | `docs(docs): sync <STORY-KEY> reference docs` (via `conventional-commit`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| PR title          | `docs(docs): sync <STORY-KEY>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| PR base           | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Diff source       | Two sources, selected per [§26](#26-dual-diff-source--selection-rule) — **story-branch-vs-base**: `CHANGED_FILES=$(git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH")` and `CHANGED_DIFF=$(git diff "origin/<BASE-BRANCH>...$STORY_BRANCH")`, both from the same three-dot range, against the **remote-tracking** base ref (checkout-independent — a stale local base never skews the diff), after `git fetch origin --quiet`; or **merged-commit** (§26) when the story branch is absent. Standalone `sync` selects whichever §26 resolves; the post-QA phase (§25) always passes story-branch-vs-base explicitly.                                                                                                                  |
| First-run PR      | Create the branch, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Re-run behaviour  | **Open or update** (AC6): before creating, check whether `docs/sync-<STORY-KEY>` already exists on `origin` (`git rev-parse --verify origin/docs/sync-<STORY-KEY>` / `gh pr list --head docs/sync-<STORY-KEY>`). If it does → check it out, **`git reset --hard` onto the freshly regenerated state** (the branch content is fully derived, so a hard reset is safe and keeps history clean), then **`git push --force-with-lease`** to update the existing open PR — never open a duplicate PR.                                                                                                                                                                                                                                               |
| Control-flow tail | Mirror `refs/adr-pipeline.md`'s §3a command-layer flow: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR — the manifest-absent silent no-op, a usage STOP, the merged-commit **zero-match STOP** (§26 — the story branch is absent **and** no landed commit carries the key), or a clean "nothing changed" no-op — release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh`; only the manifest-absent path is silent. A **merged-commit match** (§26) regenerates and proceeds to a PR like the story-branch-present case — it is no longer a release-without-a-PR path. |

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

## 10. Release mode — merged-story enumeration

Release aggregates work **already merged to base**, so the diff source is `origin/<BASE-BRANCH>` —
never a story branch (contrast §7, where `sync` cuts from the story branch head).

Every git failure here is a **STOP**, never a silent fallthrough into the "no tags yet" branch.
Discriminating the two needs **positive pre-checks**, not stderr matching alone: git exits `128`
for both "no tags exist" and unrelated fatals, and a **shallow clone with no reachable tags emits
the identical `fatal: No names found` text** as a genuine first release. Stderr therefore cannot
separate them; the shallow pre-check is what makes the fallthrough safe.

```bash
git fetch origin --tags --quiet || STOP "git fetch failed"

# The base ref must resolve BEFORE any describe — an unresolvable base is a STOP,
# never a "no tags yet" first-release run.
git rev-parse --verify --quiet "origin/<BASE-BRANCH>^{commit}" >/dev/null \
  || STOP "cannot resolve origin/<BASE-BRANCH>"

# POSITIVE shallow pre-check. A shallow clone can hide every tag and still fail describe
# with the identical "No names found" text, so it MUST be excluded before that text is trusted.
[ "$(git rev-parse --is-shallow-repository)" = "false" ] \
  || STOP "shallow clone — cannot enumerate the release range (run: git fetch --unshallow)"

# Session-scoped temp dir (./.tmp/<key>), removed by scripts/cleanup-tmp.sh /
# session-complete.sh on every exit path incl. STOP — never a bare, un-trapped mktemp.
TMP="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh")"
DESCRIBE_ERR="$TMP/describe.err"

if LAST_TAG=$(git describe --tags --abbrev=0 "origin/<BASE-BRANCH>" 2>"$DESCRIBE_ERR"); then
  RANGE="$LAST_TAG..origin/<BASE-BRANCH>"        # tagged: exclusive of the tag, inclusive of head
elif grep -q 'No names found' "$DESCRIBE_ERR"; then
  LAST_TAG=""                                    # genuine "no tags yet" — first-ever release
  RANGE="origin/<BASE-BRANCH>"                   # SINGLE-ENDED: full history to head, root inclusive
else
  STOP "git describe failed: $(cat "$DESCRIBE_ERR")"
fi
```

- **Only `No names found` falls through**, and only _after_ the shallow pre-check passed. Do **not**
  also match `No tags can describe` — that text belongs to `--contains` / no-`--tags` invocations and
  cannot be emitted by `git describe --tags --abbrev=0`; matching it would be a dead alternate
  implying a discrimination this code does not perform.
- **No tags (first-ever release)** → the range is the **single-ended** `origin/<BASE-BRANCH>`.
  Deliberately **not** `"..origin/<BASE-BRANCH>"` (git defaults the omitted left side to `HEAD`,
  which on an up-to-date base checkout yields an **empty** range → a "no stories merged" no-op → the
  first-ever release silently shipping nothing while reporting success). Deliberately **not**
  `<root-sha>..origin/<BASE-BRANCH>` either — that form **excludes** the root commit. The
  single-ended form is the only one that is both non-empty and root-inclusive.

### Enumeration format (delimited, machine-parseable)

```bash
# US (0x1f) separates fields; RS (0x1e) terminates each commit record.
# git does NOT forbid these bytes in a commit message — it stores and replays them verbatim —
# so this format is chosen because they are vanishingly rare in practice, not because they are
# impossible. A message containing a literal RS/US will mis-split; accepted for v1 because the
# failure is loud and local (a garbage key/summary surfaces at the founder-confirm gate, where a
# human is already reading), not silent corruption of a written byte.
git log "$RANGE" --format='%s%x1f%b%x1e'
```

**Why not `--format='%s%n%b'`.** That format emits **no record separator and no field separator**,
and bodies are multi-line — so there is no way to tell where one commit's body ends and the next
commit's subject begins. Every downstream rule that says "the commit that carried the key", "the
subject", "the body", or "the most recent commit" is then underivable. The delimited format above is
what makes those rules implementable; **do not simplify it back.**

**Parsing.** Split on RS (0x1e) into records. Two mechanical rules are required, because `git log`
emits a newline after each record terminator:

1. **Strip one leading `\n`** from each record (every record after the first carries it).
2. **Drop the final element** — the newline after the last RS leaves a trailing whitespace-only
   element that is not a commit.

Then split each surviving record on US (0x1f) into `(subject, body)`. A record that does not yield
exactly 2 fields is malformed — surface it and STOP rather than guessing at field boundaries.

### Story-key extraction

For each record, extract Jira story keys from **subject and body**, then take the de-duplicated
union across records. Each key retains the `(subject, body)` of the record(s) that carried it.

**Scope the regex to the consumer's Jira project key(s) — a set, not a single key.** Resolve
`PROJECT_KEYS`:

1. The **primary** key: `.claude/project/project-context.md`'s "Jira project key".
2. Any **additional** keys: `.claude/project/docs-manifest.md`'s optional "Additional Jira project
   keys" field (see `refs/docs-manifest-template.md`) — a comma-separated list of legacy or
   secondary project keys whose commits should also be recognised (e.g. a repo migrated from an old
   Jira project key to a new one still carries old-key references in its history that must not be
   silently dropped from the changelog). When parsing the "Additional Jira project keys" section
   body, **ignore HTML-comment spans, whitespace, and any `<...>`-bracketed placeholder token** —
   a section whose only non-whitespace content is a comment (e.g. a founder commented out their
   keys) or an unfilled `<...>` placeholder resolves to the **empty** additional-keys set (falling
   back to the primary key alone). The `<...>` skip is load-bearing, not merely defensive:
   `refs/docs-manifest-template.md`'s own section prose shows the shape as
   `<comma-separated list of legacy or secondary Jira project keys, e.g.: ET>` — a founder who
   copies that line verbatim to see the format and forgets to replace it would otherwise feed the
   bare `ET` to this resolver as a real key, silently scoping `release` to `ET-*`. Stripping any
   `<...>` span before parsing closes that hole regardless of what example text the template shows.

`PROJECT_KEYS` is the union of both. Build the regex as an alternation over the set, still anchored
so it cannot degrade into the unscoped form:

```text
\b(?:KEY1|KEY2|...)-[0-9]+\b
```

**Why a set, not one key.** An earlier version of this rule scoped to a single primary key. That
closes the false-positive defect below, but **regresses on any multi-project repo**: a repo whose
history carries both a current key (e.g. `NA-*`) and a legacy key from before a Jira project rename
(e.g. `ET-*`) would silently drop every commit whose only key is the legacy one from the merged-story
set — the founder-confirm gate then presents a changelog that omits shipped stories, and the PR
merges it, with nothing surfacing the gap. This repo is itself such a case (its own history carries
both `NA-*` and `ET-*` keys). A key **set** — primary plus any additional keys the founder configures
— fixes this without reopening the false-positive hole, because every key in the set is still an
exact, configured literal, never a generic pattern.

A bare `[A-Z][A-Z0-9]*-[0-9]+` (matching **any** uppercase-alnum-dash-digits token, not a configured
key) is **too loose** and false-positives on ordinary prose — `UTF-8`, `RFC-2119`, `SHA-1`,
`ISO-8601`, and `AES-256` all match it, each of which would emit a bogus `UTF-8 — <summary>`
changelog line. If `PROJECT_KEYS` is empty (project-context carries no Jira project key and the
manifest lists no additional keys), fall back to the loose regex and note the risk in the gate
output — never silently emit unfiltered matches. If `PROJECT_KEYS` is non-empty, always use the
alternation above — even when it resolves to a single key — never the loose regex.

### Out-of-scope key warning (AC3 — gated on PROJECT_KEYS ≠ ∅)

This warning is a **pure announcement overlay** on the emission above — it never changes what is
emitted, only what is _announced_. It exists solely to surface keys that emission **drops**, and
emission only drops keys when `PROJECT_KEYS ≠ ∅` (the strict alternation is in force). Therefore
**the entire computation and every print below is guarded by `PROJECT_KEYS ≠ ∅`.**

**When `PROJECT_KEYS = ∅` (State A):** the loose fallback emits **every** shape-matched token, so
**nothing is out-of-scope** and this warning is **skipped entirely** — no computation, no no-op
override. The `∅` case already carries the loose-fallback gate risk note above; NA-60 adds nothing,
and **never routes `∅` into a suppressing no-op.** The run proceeds/emits exactly as this section
already defines.

**When `PROJECT_KEYS ≠ ∅`**, compute the following over the `(subject, body)` records already
enumerated for `RANGE` (no second enumeration, no `gh`, no network):

| Set                 | Definition                                                                                                                                                                                                  |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SHAPE_MATCHES`     | every **distinct** token matching the loose shape `\b[A-Z][A-Z0-9]*-[0-9]+\b` — the superset of what any emission mode could match                                                                          |
| `IN_SCOPE`          | tokens whose **prefix** (the `[A-Z][A-Z0-9]*` head — the char class admits no `-`, so it is unambiguous) is a member of `PROJECT_KEYS`. Exactly what NA-53 emits here.                                      |
| `OUT_OF_SCOPE`      | `SHAPE_MATCHES − IN_SCOPE` — every shape-matched token emission **drops**.                                                                                                                                  |
| `LIKELY_KEYS`       | `OUT_OF_SCOPE − (prefix ∈ STANDARDS_TOKEN_DENYLIST)` — out-of-scope tokens **not** matching a known-standards prefix → **listed individually** in the warning. **The warning fires iff `LIKELY_KEYS ≠ ∅`.** |
| `STANDARDS_MATCHES` | `OUT_OF_SCOPE ∩ (prefix ∈ STANDARDS_TOKEN_DENYLIST)` — out-of-scope tokens matching a known-standards prefix → **summarized in one aggregated line, never dropped**                                         |

`IN_SCOPE` is subtracted **first**, so a configured key sharing a denylisted prefix is never
mis-handled — it is removed as in-scope before the denylist is ever consulted.

**The trigger is `LIKELY_KEYS ≠ ∅`, never `OUT_OF_SCOPE ≠ ∅` (State C, refined).** `OUT_OF_SCOPE`
is a superset that also contains `STANDARDS_MATCHES`, and `STANDARDS_MATCHES` is a **demoted
addendum shown only inside an already-firing warning — it is never, by itself, what fires the
warning.** A range whose only out-of-scope tokens are standards-prefixed (e.g. commit bodies citing
`RFC-2119`/`SHA-256`, zero genuine unrecognised keys) has `LIKELY_KEYS = ∅` even though
`OUT_OF_SCOPE ≠ ∅` — that range takes the **clean** no-op (or the normal gate, no warning line), not
the warning path. Gating on `OUT_OF_SCOPE ≠ ∅` instead would fire a warning with an **empty**
individual-key list under an active header and a "register this as a Jira project" footer, driven
entirely by standards noise — exactly the inversion AC4's demotion exists to prevent. Every part of
the warning below — the header, the count, the individual list, the standards-demotion line, and the
remediation footer — is gated as **one unit** on `LIKELY_KEYS ≠ ∅`; none of them renders on its own.

**`STANDARDS_TOKEN_DENYLIST` (fixed plugin constant, prefix-level):** `{ UTF, SHA, AES, RFC, ISO }`,
seeded from this repo's verified false-positives. It is a **display demotion, never a suppression**
(AC4). Emission continues to rely on `PROJECT_KEYS` scoping alone — the denylist changes only the
_prominence_, never the _presence_, of the notice:

- `LIKELY_KEYS` → listed individually (they look like real missing stories).
- `STANDARDS_MATCHES` → folded into a single aggregated, clearly-demoted line that is **still shown**,
  whose parenthesised prefix list is **the distinct set of prefixes actually folded this run**
  (interpolated from `STANDARDS_MATCHES`), never fixed illustrative text:

```text
(M token(s) matched common-standards prefixes (<distinct folded prefixes, e.g. RFC, SHA>) and were not listed individually — if any names a real Jira project, add its prefix as above.)
```

`M` is `|STANDARDS_MATCHES|` — a distinct variable from the warning's own total-dropped count
(`N` in `commands/docs.md`'s warning text, `= |LIKELY_KEYS| + |STANDARDS_MATCHES|`), never the same
letter as the total. This line renders only when `STANDARDS_MATCHES ≠ ∅` **and** the warning is
already firing (`LIKELY_KEYS ≠ ∅`) — it is an addendum inside a firing warning, never a trigger on
its own.

**Invariant (must hold on every path): no shape-matched out-of-scope token is ever dropped with zero
notice.** A token is emitted (`∈ PROJECT_KEYS`), listed individually (`LIKELY_KEYS`), or counted in
the summary line naming its prefix (`STANDARDS_MATCHES`). A real Jira project literally keyed `RFC`
(`RFC-14`) is **indistinguishable by shape** from the standard `RFC-2119`, so a full-suppression
denylist would either over-warn on the standard or silently drop the real key — which is why the
denylist **cannot** suppress. `RFC-14` is folded into the summary, whose interpolated prefix list
shows `RFC`, and the founder — reading "if any names a real Jira project, add its prefix" against a
prefix they recognise — adds it. No silence, no anonymous count.

**Who computes and prints it:** the **command layer** (`commands/docs.md`) computes `OUT_OF_SCOPE`
and its `LIKELY_KEYS`/`STANDARDS_MATCHES` partition at its release route (it already runs this §10
enumeration and owns the interactive gate), fires the warning **iff `LIKELY_KEYS ≠ ∅`**, and prints
it at the no-op branch (§14) or the founder-confirm gate. This ref owns only the definitions.
`agents/knowledge-engineer.md` is **not** involved — it never renders the gate.

**"Most recent" is well-defined:** `git log` emits newest-first by default, so for a key appearing in
several records, the **first** record encountered is its most recent commit. Do not add `--reverse`
without also inverting that rule.

`gh` is **not** consulted for any content that lands in a file — see §11's `gh` boundary.

## 11. Release mode — changelog aggregation + upsert

### Aggregation inputs (repo-derived, no network)

Change type and summary both come from the `(subject, body)` records §10 already parsed — the
**subject** for type and summary, the **body** for the breaking-change footer. No additional git
call and **no network call** is needed.

| Need        | Repo-derived source (always available)                                                                                                                                                                                                                                                                                                                                                                           |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Change type | The **subject's** conventional-commit `type`: `feat` → **Added**; `fix` → **Fixed**; any other recognised type (`refactor`/`perf`/`docs`/`chore`/…) → **Changed**. Promoted to **Breaking** by a `!` marker in the subject (`feat!:`) **or** a line-anchored `BREAKING CHANGE:` footer in the body. A subject with **no** parseable prefix → **Changed** (the neutral bucket — never dropped, never guessed at). |
| Summary     | The **subject's** description text — the remainder after `type(scope):` — used verbatim, trimmed.                                                                                                                                                                                                                                                                                                                |

- **The `BREAKING CHANGE:` test is line-anchored, never a substring search.** Per Conventional
  Commits it is a **footer**: the token must begin a line — match `^BREAKING[ -]CHANGE:` (multiline)
  against the body. A body that merely _mentions_ the string in prose is **not** a breaking change.
  This is a live hazard, not a hypothetical: this repo's own history contains commit messages
  discussing `BREAKING CHANGE:` in prose, and a naive `"BREAKING CHANGE:" in body` test flags them.
- **The `gh` boundary: `gh` never contributes to written content.** `gh` MAY enrich what is
  **displayed** to the founder at the confirm gate (e.g. PR titles alongside keys); it MUST NOT feed
  any byte written to a file. Letting a `gh` lookup supply the summary would make file content depend
  on **ambient network state**: run 1 with `gh` up writes PR titles, run 2 rate-limited rewrites the
  same release with commit subjects → a non-empty `git status --porcelain` → a spurious commit that
  _degrades_ a changelog already under review, contradicting §14's idempotence contract. Written
  content is a pure function of the commit range.
- **A key appearing in multiple records** takes the highest-precedence change type among them
  (**Breaking > Added > Fixed > Changed**) and the subject of its **most recent** record as the
  summary (the first record encountered — `git log` is newest-first).
- **Deterministic ordering** (required for the byte-identical guarantee): emit sections in the fixed
  order **Breaking → Added → Changed → Fixed**, omitting empty sections. Within a section, sort story
  lines by key — project prefix lexicographically, then the numeric suffix **numerically** (so
  `NA-9` precedes `NA-53`, which a plain string sort gets wrong). Line shape: `<KEY> — <summary>`.
- **Each change-type bucket is a `###` sub-heading** (`### Breaking`, `### Added`, `### Changed`,
  `### Fixed`) — one level below the `## <VERSION>` section heading, never `## `. This is
  load-bearing for the upsert boundary below: that boundary terminates at the next `## ` heading, so
  a bucket pinned at `## ` instead of `### ` would prematurely end the section at its own first
  bucket — the upsert would then insert each re-run's fresh content **above** the stale remainder
  instead of replacing it, the changelog would accumulate duplicate `### Added`/`### Fixed` blocks
  under one `## <VERSION>`, and `git status --porcelain` would be non-empty on every re-run even
  with no new merged stories — breaking §14's "re-run with no new stories commits nothing" claim.
- **Never fabricate.** The changelog emits exactly what the commits support — no inferred prose, no
  invented summaries. A bare-key line is never emitted, because the fallbacks above always resolve
  both fields.

### Changelog file shape

The `changelog` row's `target-path` (registry default `docs/changelog/`) holds a **single cumulative
file**, `index.md` (Keep-a-Changelog style, newest-first). If it does not exist, phase 2 creates it
with this preamble — **including frontmatter**, per §12's "every written release page MUST carry
`title` + `description`" rule, which applies to this page too — then applies the upsert below:

```markdown
---
title: Changelog
description: All notable changes to this project, generated by /sdlc:docs release.
---

# Changelog

All notable changes to this project are documented in this file. Generated by
`/sdlc:docs release <version>`; each release upserts its own `## <VERSION>` section.
```

Omitting the frontmatter here would silently break §14's `llms.txt` regen, which derives every
entry's `title`/`description` from page frontmatter: since this preamble is written **once** and
never revisited (the upsert boundary below explicitly never touches it), a missing frontmatter
block would either drop the changelog from `llms.txt` forever, or make the regen STOP on a page it
expects to carry frontmatter — after the founder has already confirmed the release content.

### Upsert rule

Maintained by **upsert**, not unconditional prepend. A prepend-only rule contradicts §14, because
`release` creates no tags, so a re-run of a version whose PR already merged would find its
`## <VERSION>` section present and prepend a **second** one.

1. **Scan** the cumulative file for an existing `## <VERSION>` heading (exact match on the
   **normalised** `VERSION` — which is what makes `## 1.4.0` and `## v1.4.0` a single stable
   spelling rather than two sections).
2. **Section exists** → **replace it in place**: swap the section's body for the freshly aggregated
   content, leaving its position and every other section byte-identical. A re-run with no new merged
   stories therefore rewrites the section with identical bytes → empty `git status --porcelain` → no
   commit, no PR.
3. **Section absent** → **prepend** a new `## <VERSION>` section above the newest existing section,
   preserving newest-first ordering.

The upsert boundary is the `## <VERSION>` heading and everything up to (not including) the next
`## ` heading or EOF — **including** the `### `-level change-type sub-headings inside it, which are
section body, not section boundaries (see "Deterministic ordering" above; change-type buckets MUST
use `### `, never `## `, or the boundary detection breaks). The file's preamble is never touched.

## 12. Release mode — ADR-link resolution + artifact set

### ADR-link resolution

For each merged-story key, resolve its **motivating ADR** by scanning `docs/adr/**` frontmatter for
any ADR whose `source-stories:` list contains that key (the join key established by
`refs/adr-pipeline.md`):

- **Match** → the release note for that story links the ADR (relative link to the
  `docs/adr/NNNN-*.md` page, using the ADR title).
- **No match** → the note **omits** the ADR link entirely. Never fabricate, guess, or invent an ADR
  reference. A story with no ADR simply has an ADR-less note.
- Multiple ADRs may cite the same story → link each.
- The scan is **read-only** against `docs/adr/` at `origin/<BASE-BRANCH>` head — resolve it
  checkout-independently (`git ls-tree -r --name-only origin/<BASE-BRANCH> -- docs/adr` then
  `git show origin/<BASE-BRANCH>:<path>` per hit), never out of the working tree.
- **No `docs/adr/` directory at all** → every note is ADR-less. Not an error.

### Artifact set

Each artifact maps onto an existing `writing-docs` quadrant template and its registry `target-path`;
the **normalised** `VERSION` is the identifier. **A row is only in play when it is in
`ENABLED_ROWS`.**

| Artifact          | Quadrant    | `writing-docs` template | Default `target-path`    | Convention                                                                          |
| ----------------- | ----------- | ----------------------- | ------------------------ | ----------------------------------------------------------------------------------- |
| `changelog`       | reference   | Reference               | `docs/changelog/`        | Single **cumulative** `index.md`; each release **upserts** its `## <VERSION>` (§11) |
| `release-notes`   | explanation | Explanation             | `docs/release-notes/`    | **One page per version**, `<VERSION>.md`; each note links its motivating ADR(s)     |
| `migration-guide` | how-to      | How-to                  | `docs/migration-guides/` | **One stub page per version**, `<VERSION>.md` — headings/scaffold only              |

- The **changelog** is a gated artifact but **not a narrative one**: its body is a mechanical
  aggregation of the commit range (§11), so the founder confirms an aggregation, not prose.
- **Release notes** are explanation-quadrant prose per `writing-docs` — one entry per merged story,
  each linking its motivating ADR when one exists. Fully narrative, fully gated.
- The **migration-guide stub** is headings/scaffold **only** — emit exactly:

  ```markdown
  ## Breaking changes

  ## Upgrade steps

  ## Rollback
  ```

  with **no body prose** under any heading. Deep migration content is explicitly out of scope.

### Page frontmatter (required — `llms.txt` reads it)

§8's `llms.txt` regen derives each entry from the generated page's frontmatter, so every written
release page MUST carry:

```yaml
---
title: <human title, e.g. "Release notes — 1.4.0">
description: <one line, used verbatim as the llms.txt description>
---
```

The migration-guide stub is a `how-to` page but **must NOT carry a `source:` key** — §5 makes a
`source:`-less how-to page one that `sync` never auto-refreshes, which is the intended behaviour for
a per-version stub (a release artifact is owned by the release that cut it, not re-drafted by a
later `sync`).

## 13. Release mode — branch / PR / control flow

> **Divergence from §7 — do not harmonise.** §7 (`sync`) resets the branch onto regenerated state
> and force-pushes with `--force-with-lease`, which is safe there because `sync`'s branch content is
> **fully derived**. A release branch is **not** fully derived: the control-flow tail drives
> `/loop /sdlc:loop` against it, so it carries review-fix commits not derived from the drafts.
> `reset --hard` and force-push are therefore **prohibited** on release paths. Re-run convergence
> comes from idempotence, not from rewriting history.

| Item                      | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branch                    | `docs/release-<VERSION>` (the **normalised** version — `1.4.0` and `v1.4.0` resolve to the same branch, never two), cut from the **base branch head** (`origin/<BASE-BRANCH>`) — **not** a story branch. Release aggregates work already merged to base, so the base tree is the correct source.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Commit                    | `docs(docs): release <VERSION>` (via `conventional-commit`), carrying the trailer `Release-Generated: <VERSION>`. **The trailer is load-bearing**, not decoration: it is the only reliable marker of "this pipeline wrote this commit", and both guards below key on it. Subject-matching is not a substitute.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| PR title                  | `docs(docs): release <VERSION>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Local-branch precondition | Applies on **every** path, first-run and re-run alike, checked **before** either. If a **local** `docs/release-<VERSION>` exists holding commits not reachable from `origin/docs/release-<VERSION>` (or, when no such remote exists, any commits at all beyond `origin/<BASE-BRANCH>`) → **STOP**: `local branch docs/release-<VERSION> has unpushed commits; push, drop, or rename it, then re-run.` Never `checkout -B` over it. Hoisted out of the re-run rows deliberately: the first-run path is defined by the branch being absent **on `origin`**, which says nothing about a local branch of the same name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| First-run PR              | No remote branch (`git rev-parse --verify origin/docs/release-<VERSION>` fails) → after the precondition passes, create the branch from `origin/<BASE-BRANCH>` head, write, commit, push, open the PR against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Re-run behaviour          | **Open or update; the branch's commits are never rewritten.** If the branch exists on `origin` → `git fetch origin`, run the precondition + **both guards**, then check it out **at its remote head**: `git checkout -B docs/release-<VERSION> origin/docs/release-<VERSION>` — **the single normative flow**. Write the regenerated content **on top** as a new commit and `git push` (plain fast-forward). A re-run with nothing to change produces **no commit, no push, no duplicate PR**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Re-run history guard      | The **one forbidden path**: no re-run may reset the branch onto regenerated state, force-push it (`--force` / `--force-with-lease`), or discard any commit reachable from `origin/docs/release-<VERSION>`. A reset-to-regenerated + `--force-with-lease` would _succeed_ (the local ref was just fetched) and silently revert the PR to unreviewed content. Checking out at the remote head does none of these — it adopts the remote's commits rather than replacing them.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Re-run content guard      | Preserving commits protects **history**; this guard protects **content**. Before writing, find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path phase 2 writes this run** and **lack the `Release-Generated: <VERSION>` trailer** — i.e. out-of-pipeline edits to generated pages. This path set is **not** just the `ENABLED_ROWS` target-paths: phase 2 also unconditionally rewrites `llms.txt` (when §14 determines its row is enabled) and, per §14's "doc index" bullet, any existing `release-notes`/`migration-guides` section index page it regenerates — a `/sdlc:loop` review-fix or founder edit to either of those is exactly the kind of out-of-pipeline content this guard exists to protect, and scoping the scan to `ENABLED_ROWS` alone would silently destroy it with no STOP. If any qualifying path is found → **STOP**: `branch docs/release-<VERSION> carries edits to generated pages (<paths>) that this pipeline did not write; re-running would overwrite them — merge or close PR #<n>, or drop those edits, then re-run.` Necessary because phase 2 writes confirmed drafts **verbatim** and §11's upsert replaces the section body unconditionally. Trailer-bearing commits, and commits touching **other** paths, do not trip it — proceed. |
| Control-flow tail         | Mirror §7 / `refs/adr-pipeline.md`'s §3a: after the PR is raised, drive the review loop via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, no-row-enabled no-op, no-stories-merged no-op, an invalid-version STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

### Where edits live, and what a re-run does to them

| Edit made…                                                                                | Committed by                                                 | A re-run…                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **At the founder-confirm gate** (the founder edits a draft before confirming it)          | phase 2, carrying the `Release-Generated: <VERSION>` trailer | **Re-derives it.** Phase 1 re-drafts from the commit range every run and the gate re-presents the machine draft — a prior run's gate edit is **not** carried forward. To keep it, re-apply it at this run's gate. Not silent, but **not preserved either**. |
| **On the branch, outside the pipeline** (a `/sdlc:loop` review-fix commit, a direct push) | anything **without** the trailer                             | **STOPs** (re-run content guard) — refuses to overwrite it and hands the decision back to the founder.                                                                                                                                                      |

The distinction is the **trailer, not the commit subject**. Keying on the subject would be wrong:
phase 2 commits founder gate edits under exactly the normal `docs(docs): release <VERSION>` subject,
so a subject test classifies them as pipeline-authored and the guard never fires — correct for gate
edits (re-derived by design), but it must not be mistaken for _preserving_ them.

## 14. Release mode — no-op / change-gate semantics

- **Manifest-absent silent no-op.** See [§1's Manifest gate](#manifest-gate-shared-by-sync-release-seed-and-audit)
  (shared with `sync`) — the command layer never dispatches when that gate finds the manifest
  genuinely absent, distinct from the STOP the same gate raises first if `origin/<BASE-BRANCH>`
  itself won't resolve. Not something phase 1 checks. The zero-setup-cost guarantee for repos that
  declined the `/init` docs opt-in.
- **No release row enabled → clean no-op.** Print `no release-triggered doc types enabled in
docs-manifest.md — nothing to generate` and exit without a PR. **Informational, not silent** — the
  manifest exists, so the founder opted in; a fully-disabled release surface is worth surfacing
  (mirroring `sync`'s "found nothing to do" vs "opted out" distinction).
- **No stories merged → split by `LIKELY_KEYS` (§10), never by `OUT_OF_SCOPE`.** The emitted set
  here is NA-53's `IN_SCOPE`. When `PROJECT_KEYS ≠ ∅`, `OUT_OF_SCOPE` (and its `LIKELY_KEYS` /
  `STANDARDS_MATCHES` partition) is computed over the full range **regardless of whether `IN_SCOPE`
  is empty** (§10), so this no-op splits **on `LIKELY_KEYS`, one mutually-exclusive state — never
  both branches for the same range:**
  - emitted set `= ∅` **and** (`PROJECT_KEYS = ∅` **or** `LIKELY_KEYS = ∅`) → the existing clean
    no-op, interpolating `LAST_TAG` **only when set** (never an empty interpolation):
    - `LAST_TAG` set → `no stories merged since <LAST_TAG> — nothing to release`
    - `LAST_TAG` empty → `no stories merged since the start of history — nothing to release`
    - **`LIKELY_KEYS = ∅` covers the standards-only case too** — a range whose only out-of-scope
      tokens are standards-prefixed (`STANDARDS_MATCHES ≠ ∅` but `LIKELY_KEYS = ∅`) takes this clean
      branch, not the warning branch (see §10's refined State C — the demotion must never itself be
      what suppresses "nothing to release").
  - emitted set `= ∅` **but** `PROJECT_KEYS ≠ ∅` **and** `LIKELY_KEYS ≠ ∅` → **the warning no-op**
    (the pure silent-drop case — at least one genuine unrecognised key exists). Print the §10 warning
    (out-of-scope keys + section-aware remediation, per `commands/docs.md`); the message must **not**
    claim unqualified "nothing to release". Exit 0, still **no PR** — the pipeline never fabricates a
    release from unconfigured keys; it prompts the founder to configure and re-run.

  Because the split is keyed on the single variable `LIKELY_KEYS` (empty vs. non-empty), the two
  branches above are **structurally mutually exclusive** — no range can match both, so there is no
  precedence question and no risk of a legacy-key range silently falling into the clean branch.

- **Commit/PR only on actual content change.** Phase 2 commits only if `git status --porcelain` on
  the written paths is non-empty. If the founder rejected every draft and the deterministic regen
  produced byte-identical output → no commit, no PR, clean exit. If the founder rejected the
  narrative drafts **but** the deterministic `llms.txt`/index changed → still commit + PR.
- **`llms.txt` regenerated every run, committed only if changed.**

### Re-run / idempotence contract

Re-running `release <VERSION>` over the **same commit range**, with the founder confirming the
**same content**, recomputes **byte-identical** content for every enabled row, leaves
`git status --porcelain` empty, and therefore commits nothing and opens no PR.

**The claim is scoped, and the scope is load-bearing.** It is a statement about the _generator_:
same range + same confirmed content → same bytes. It does **not** claim edits survive a re-run
untouched — see §13's "Where edits live". Five things are load-bearing; none may be dropped:

1. **`VERSION` normalisation** — one spelling per release, so a re-run targets the same branch, PR,
   pages, and changelog section rather than creating a parallel set.
2. **Changelog upsert** (§11) — a re-run rewrites its section in place instead of prepending a duplicate.
3. **A parseable enumeration** (§10) — the RS/US delimited format; without it "the commit that
   carried the key" is underivable and the aggregation is not a function of anything well-defined.
4. **Content is a pure function of the commit range** (§11) — no `gh`, no network, no ambient state
   may reach a written byte, or "byte-identical" would depend on whether `gh` happened to answer.
5. **Non-destructive branch re-use** (§13) — a re-run preserves every commit on the branch (never
   resets onto regenerated state, never force-pushes) and STOPs rather than overwrite out-of-pipeline
   edits to generated pages.

### Deterministic index + `llms.txt` regen

After the confirmed narrative writes, phase 2 deterministically regenerates the doc index and
`llms.txt` — the un-gated half of the run (the same "auto rows are un-gated" discipline `sync` applies):

- **`llms.txt`** — **only if the `llms-txt` row is present and enabled in the manifest.** `llms-txt`
  is a `sync`-triggered row, not a `release`-triggered one, so it is **not** a member of
  `ENABLED_ROWS` (`commands/docs.md`'s Enabled-row gate covers only the three release rows) —
  release must independently re-check the manifest's `llms-txt` row state before touching this
  file. Absence is
  never inferred as enabled, the same discipline as `ENABLED_ROWS`'s row-absence rule: a founder who
  declined `llms-txt` at `/init` (row absent, per `docs.md`'s "Absent is never default-on" rule)
  must never have it written or overwritten by a `release` run either. If disabled or absent, phase 2
  does not write or touch `llms.txt` at all this run — any existing file is left exactly as-is. When
  it **is** enabled: reuse §8's algorithm verbatim — index-only, grouping the generated pages of
  every enabled `public: yes` row by Diátaxis quadrant, each entry a `title — one-line description —
relative link` derived from page frontmatter (§12 specifies the frontmatter release pages emit).
  The newly written release pages now appear in it. Idempotent; committed only if changed.
- **The doc index** — for the `changelog` target-path, the cumulative file **is** the index of
  releases (newest-first), maintained in place by §11's upsert. For `release-notes` /
  `migration-guides`, if the row is enabled **and** the consumer's docs tree already carries a
  section index page at that path, regenerate it deterministically (**upsert** the `<VERSION>` entry
  — add if absent, rewrite in place if present; never append a duplicate). If none exists,
  `llms.txt` is the sole index and no separate section index is created. No new index file type is
  invented.

## 15. Seed mode — type resolution + topic validation

### `SEED_TYPES` — registry-derived, never hardcoded

`SEED_TYPES` resolves **at read time** from `refs/doc-types.md`: every row whose `trigger` cell
contains the `seed` token, **minus `adr`** (routed to `refs/adr-pipeline.md`, not the generic seed
machinery). Today that resolves to `concept`, `tutorial`, `integration-guide`, and `how-to`.

**Why derived and not a literal list in `docs.md`.** `refs/doc-types.md` is the stated single source
of truth for `trigger` (`docs-manifest-template.md`: consumers "derive all four from
`refs/doc-types.md` at read time"). A hardcoded list would be a second copy of a normative fact and
would drift the moment a row's `trigger` changes. `seed` reads the registry; the registry decides.
Any message that enumerates the valid types **renders the resolved `SEED_TYPES`** — it never types
the list as a literal, or it becomes the copy this rule exists to avoid.

`refs/doc-types.md` unreadable or malformed → surface the failure and **STOP**. Never resolve
`SEED_TYPES` from a partial registry, and never fall back to a hardcoded list.

**`adr` is excluded from `SEED_TYPES` rather than admitted-then-rejected downstream**, so no `adr`
run can reach the manifest gate, the branch, or the write path. `seed adr` is a **special route**
to `refs/adr-pipeline.md` (`commands/docs.md` step 7), not a generic `SEED_TYPES` member — an ADR
is a numbered `docs/adr/NNNN-slug.md` file, not a single narrative page.

### Topic validation + slug normalisation

`<topic>` is founder prose. `SLUG` is derived from it, and `SLUG` — not the raw topic — forms a git
branch name (`docs/seed-<type>-<SLUG>`) and a file path (`PAGE`, §16).

```text
SLUG = slugify(topic):
  1. trim, lowercase
  2. replace every run of characters outside [a-z0-9] with a single "-"
  3. collapse repeated "-", then strip leading and trailing "-"

SLUG must additionally satisfy, or the run STOPs:
  - non-empty
  - no longer than 80 characters
  - not a reserved page id (see below)
```

**The ladder is one rule with two entry points, and both go through it.** A supplied `<topic>` and a
prompted `<topic>` are validated and slugged by the **same** rule. A ladder applied only to the CLI
argument would be trivially bypassed by omitting the argument and typing the same hostile string at
the prompt — validation the primary input path never reaches is not validation.

**Normalisation is identity-forming, not cosmetic.** `Offline Sync`, `offline-sync`, and
`  Offline   Sync!  ` all slugify to the same `SLUG` (`offline-sync`) — one branch, one PR, one page
— rather than three parallel branches and three duplicate pages for one topic.

| Raw `<topic>`        | `SLUG`         | Note                                  |
| -------------------- | -------------- | ------------------------------------- |
| `My Topic`           | `my-topic`     | —                                     |
| `my-topic`           | `my-topic`     | identical to the above — one identity |
| `  Offline   Sync  ` | `offline-sync` | whitespace runs collapse              |
| `../../oops`         | `oops`         | traversal characters cannot survive   |
| `a/b/c`              | `a-b-c`        | path separators cannot survive        |
| `1.4.lock`           | `1-4-lock`     | see the `.lock` note below            |
| `x..y`               | `x-y`          | `..` cannot survive                   |
| `@{`                 | _(empty)_      | → STOP                                |
| `...` / `----` / `-` | _(empty)_      | → STOP                                |
| `日本語` / `☕`      | _(empty)_      | → STOP                                |

**Three failure modes are reachable, and all three are real. Do not add a fourth.** The slugify
charset is `[a-z0-9-]`, which makes several rules that look like they belong here — by analogy with
§13's version ladder — **structurally vacuous**. A vacuous rule is not free: NA-53 shipped a `.lock`
check that rejected nothing and an unreachable trailing-`-` STOP whose message misdescribed its
input, and both survived review because nobody tested them. So, explicitly:

- **No `..` rule.** `.` is not in the charset; `x..y` → `x-y`. Unreachable.
- **No `.lock` rule.** `1.4.lock` → `1-4-lock`. Verified:
  `git check-ref-format --branch docs/seed-concept-1-4-lock` → **valid**. A `SLUG` cannot end in
  `.lock` because it cannot contain a `.`. Unreachable. (§13 needs this rule; `seed` does not.
  **Do not add it "for parity".**)
- **No trailing `.`/`-` rule.** Step 3 strips them. `topic-` → `topic`, `topic.` → `topic`.
  Unreachable.
- **No path-separator rule.** `/` is not in the charset. Verified: `../../oops` → `oops`. The docs
  tree cannot be escaped by construction — a stronger guarantee than a rejection regex, because no
  input reaches the write path unsanitised. **This guarantee governs the slug; it does NOT extend to
  the `target-path` the slug is joined to — see §16's `PAGE` construction.**

The three rules that **are** reachable:

- **Empty `SLUG`** → STOP. Reachable two ways — punctuation-only input (`...`, `@{`) and
  **non-ASCII-only input** (`日本語`, `☕`), both verified empty:

  ```text
  invalid topic "<raw>" — must contain at least one ASCII letter or digit
  (the page id and branch name are derived from it)
  ```

  Say **ASCII letter or digit**, not "letters or digits": `日本語` _is_ letters, and a message
  claiming otherwise would misdescribe the input in front of the founder — exactly what NA-53's
  unreachable trailing-`-` STOP got wrong.

- **`SLUG` longer than 80 characters** → STOP:

  ```text
  invalid topic "<raw>" — the derived page id is <n> characters; shorten the topic to 80 or fewer
  ```

  Empirically grounded: a 300-character filename fails `ENAMETOOLONG` on this repo's filesystem
  while a 200-character one succeeds — verified. **STOP rather than truncate**, deliberately:
  truncation would map two distinct long topics onto one `SLUG` → one branch, one page, one silently
  overwriting the other.

- **`SLUG` is a reserved page id** → STOP. The reserved set is **`{index}`**:

  ```text
  invalid topic "<raw>" — "<SLUG>" is a reserved page id: it is the section index
  this run regenerates. Choose a different topic.
  ```

  **The message deliberately does not name the `target-path`.** This STOP fires at the ladder, where
  `target-path` is not yet knowable (§16 step 3 resolves it). Interpolating the **registry default**
  would print `docs/concepts/` when the founder retargeted the row to `docs/explain/` — naming a path
  the run would never write. Relocating the check to obtain the value would silently move a rule that
  belongs at the ladder. The reserved id is a property of the **slug**, not the path, so the message
  stays about the slug.

  This is **not** a charset rule — `index` is a perfectly well-formed slug. It is a **collision**
  rule, and without it `seed concept index` destroys its own output inside a single run: `PAGE`
  resolves to `docs/concepts/index.md`, the page-exists gate passes (no index page exists yet, so it
  looks like a legitimate first seed), phase 2 writes the founder's page there, and **the index regen
  then fires because phase 2 just created a section index page at that `target-path`** — rewriting
  the founder's page as a generated index in the same commit.

  **Two independent rules close this, and both are required (each covers the other's gap):** this
  STOP, and §19's rule that the index-regen existence test reads the **pre-write** tree. Neither is
  redundant.

**`SLUG` (normalised), not the raw topic, is used everywhere downstream** — branch name, PR title,
commit string, page id, and the page-exists gate. The raw topic is echoed **only** in the STOP
messages above, and used verbatim **only** as the human topic handed to phase 1 for drafting.

All of these are **usage STOPs raised at the ladder** — before any branch, dispatch, draft, or
founder gate.

## 16. Seed mode — gate ladder + `PAGE` construction

The seed run reuses §2's two-phase dispatch and command-layer founder-confirm gate — **not
re-derived here**. What is seed-specific, **in this order** (the order is load-bearing):

```text
1. argument validation (§15)  →  2. manifest gate (§1)  →  3. type-activation gate
→  4. topic prompt (if omitted)  →  5. page-exists + branch-state gate (§18's precondition
   + BOTH re-run guards)  →  6. phase 1 (scaffold, writes nothing)  →  7. founder gate (authoring)
→  8. phase 2 (write + regen + commit/PR)
```

**Everything through step 5 runs before the founder authors anything, and that is the ordering
principle for the whole ladder.** For `seed`, a post-gate STOP does not merely waste a machine's
work as it would in `sync` or `release` — **it destroys the founder's entire page**. Every rejection
whose inputs are already available runs **before** the gate; where one cannot be, it must preserve
the authored content rather than discard it (§18).

1. **Argument validation** — §15's ladder, including a supplied `<topic>`. A supplied topic is
   validated **before** gates 2–3 because it forms a branch name and a path.

2. **Manifest gate (AC5)** — shared with `sync` and `release`; defined **once** in
   [§1's Manifest gate](#manifest-gate-shared-by-sync-release-seed-and-audit). `seed` is its third
   consumer and does **not** re-derive it. The base-ref pre-check ordering is load-bearing for
   exactly the reason §14 documents: a bare `git show origin/<BASE-BRANCH>:<path>` failure is
   ambiguous between "the manifest genuinely does not exist" (the intended silent no-op) and "the
   **ref** does not resolve" (a fresh/shallow CI clone, a renamed base branch). Without the
   `git fetch` + `git rev-parse --verify origin/<BASE-BRANCH>^{commit}` pre-check running **first**,
   an opted-in repo with a real manifest gets a **silent no-op reporting success while writing
   nothing**. Manifest genuinely absent → **silent no-op**: no prompt, no branch, no dispatch, no PR,
   no error, **no stdout**, exit 0.

3. **Type-activation gate (AC2).** Resolve the requested `<type>`'s row from the manifest; call it
   `SEED_ROW`. The type is **activated** iff its row is **present** in the manifest row-table **and**
   its `enabled` column is `true`.
   - **Absent is never activated.** A row **present** is enabled per its `enabled` column
     (`docs-manifest-template.md`'s Fill rules default it to `true` for every _written_ row). A row
     **absent** is **not** activated. Absence has two causes and the distinction does not matter
     here: the type was offered at `/init` and declined (recorded as a `<!-- declined: <type> -->`
     comment, which never writes a disabled row), or the row was deleted (a future re-init may
     re-offer it — `/init`'s business, not `seed`'s). **Never infer a missing row as enabled.**
   - **Not activated (absent _or_ `enabled = false`) → report and make no write**, before any prompt,
     branch, dispatch, or draft:

     ```text
     doc type "<type>" is not activated in .claude/project/docs-manifest.md — nothing seeded
     (add or enable its row to seed this type)
     ```

     **Informational, not silent** — the manifest exists, so the founder opted in; a request for a
     specific, deactivated type is worth surfacing. Deliberately distinct from step 2's silent no-op.
     Do not dispatch `knowledge-engineer`.

   - **`target-path` comes from `SEED_ROW`, not from the registry default.** The registry's
     `target-path` is a default token that `/init` pre-fills and the founder retargets; the manifest
     row is authoritative at read time.

4. **Topic resolution (prompt if omitted).** If `<topic>` was not supplied, prompt for it **now** —
   at the command layer, the only layer that can pause for input — and run the **identical** §15
   ladder on the answer. A prompted topic that fails is the same usage STOP as a supplied one.
   Placed **after** gates 2–3 so a repo with no manifest is never prompted before its silent no-op,
   and a deactivated type is reported rather than prompted for.

5. **Page-exists + branch-state gate — all of it pre-gate.** Resolves `PAGE`, decides first-run vs
   re-run, and runs **every** guard that could reject the run. All inputs (base ref, branch state on
   `origin`, commit trailers) are available now; none requires the founder's content.

   **Construct `PAGE` by normalising `target-path` first — the naive join fails OPEN.**

   ```text
   PAGE = rstrip(SEED_ROW.target-path, "/") + "/" + SLUG + ".md"
   ```

   Every registry `target-path` ends in `/` (`docs/concepts/`, `docs/tutorials/`, …), and a
   founder-retargeted one may or may not. A plain `<target-path> + "/" + <SLUG> + ".md"` yields
   `docs/concepts//offline-sync.md`. That is **not cosmetic** — it silently defeats this gate,
   because git and the filesystem **disagree** about the path:
   - `git show "origin/<BASE-BRANCH>:docs/concepts//offline-sync.md"` **does not resolve**, even
     when `docs/concepts/offline-sync.md` is published — git matches tree paths literally and there
     is no empty-named subtree. **Verified against this repo.**
   - The **filesystem collapses `//`** — writing `docs/concepts//offline-sync.md` opens
     `docs/concepts/offline-sync.md`. **Verified.**

   The gate is on the losing side of that disagreement: it concludes "exists nowhere → first run",
   phase 1 scaffolds, and phase 2 writes through the malformed path **onto the published file**,
   destroying it — the exact outcome this gate exists to prevent, with no STOP and no diff the
   founder would recognise as a delete. And because **every** registry `target-path` ships with a
   trailing slash, this is the **default** path, not an edge case.

   **Normalise once, at construction. The same `PAGE` string is then used everywhere downstream** —
   the gate, phase 1, phase 2's write, and the guard path set — **never re-joined per call site** (a
   second join is a second chance to reintroduce the defect). This is a defect-closing rule, not a
   style preference — **do not "simplify" it away.**

   **Check `PAGE` checkout-independently** at the base ref — never the working tree, for the same
   reason the manifest is read that way (a stale local checkout must not decide whether a page
   exists):

   ```bash
   git show "origin/<BASE-BRANCH>:$PAGE" >/dev/null 2>&1
   ```

   The base ref is already known to resolve (step 2's pre-check ran), so a failure here is
   unambiguous — the path does not exist at a known-good ref. Therefore:
   - **Exists at `origin/<BASE-BRANCH>`** → **STOP**:

     ```text
     <PAGE> already exists on <BASE-BRANCH> — seed authors new pages, it does not rewrite published
     ones. Edit the page directly, or re-seed under a different topic.
     ```

     `seed` is a **create** verb. Silently overwriting a published page — one that may carry months
     of hand edits and, for a `how-to`, a founder-authored `source:` list — is not scaffolding.

   - **Does not exist at base, but the seed branch exists on `origin`** → a **re-run** of an unmerged
     seed. Allowed — **but §18's local-branch precondition and both re-run guards are evaluated
     now, here, before phase 1 dispatches.**
   - **Exists nowhere** → first run. **The local-branch precondition still runs** — it applies on
     every path (a local branch of the same name with unpushed commits says nothing about `origin`).

6. **Phase 1 dispatch — scaffold & draft, writes nothing.** Inputs: `<type>`, `SEED_ROW` (its
   `target-path`), `SLUG`, the **raw** topic text, the normalised `PAGE`, and `origin/<BASE-BRANCH>`.
   Phase 1 loads `writing-docs` **unconditionally**, selects the quadrant template for `<type>`'s
   registry `quadrant` (§17), scaffolds the page filling only what the topic and (for corpus-backed
   types) the learnings corpus support — **never inventing facts to fill a section** (`writing-docs`'
   "No TBDs in published docs" rule applies, so an unsupported section is left for the founder rather
   than padded with plausible prose) — emits §17's required frontmatter, and returns the scaffold.
   **Nothing is written to disk in phase 1.**

7. **Founder-confirm gate (command layer, AC3) — this is where the founder authors.** Present the
   scaffold; the founder may **accept, edit, author over, or reject** it. Unlike `sync`/`release`,
   where the gate mostly confirms machine-derived content, **here the gate is the authoring
   surface**, and heavy editing is the expected path, not the exception. `tutorial` is `manual-only`
   in the registry — the scaffold is a skeleton and the prose is the founder's.
   - **Validate the confirmed content here, at the gate, while it still exists** — specifically §17's
     required `title`/`description` frontmatter. The gate is the **last** layer that holds the
     founder's content in an editable, interactive context; phase 2 is a fresh dispatch that receives
     it as an opaque payload. A content check deferred to phase 2 can only STOP — it cannot ask the
     founder to fix the missing line — converting a one-line correction into the loss of a whole
     authored page.
   - **"Present" is not "filled."** A `title`/`description` that is **missing** and a
     `title`/`description` that **still carries the `writing-docs` scaffold's unfilled
     `TODO(fill)` sentinel** are the **same rejection** at this gate — reject/re-prompt in either
     case; a confirmed-but-unedited placeholder is never treated as valid content. (A
     `TODO(fill)`-still-present `related-adrs:` value cannot occur — the key's own default is `[]`,
     not a sentinel — so this check is scoped to `title`/`description`, plus, when the row is
     `how-to`/`integration-guide` and `source:` is **present**, its list item(s): reject a `source:`
     whose only entry is still the scaffold's own `TODO(fill)` glob example, since a `source:` list
     holding no real glob can never intersect `CHANGED_FILES` and would silently defeat §5's
     auto-refresh the founder believed they'd opted into. A `source:` key that is **absent** is
     unaffected — omission is the documented opt-out, not a defect.)
   - **Founder rejects / does not confirm** → write nothing, no branch, no PR, no phase-2 dispatch;
     report and exit cleanly. Unlike `release`, a seed run has **no** deterministic half that could
     still be worth committing — the index/`llms.txt` regen is a _consequence_ of the page write, so
     with no page there is nothing to reindex.
   - `gh` and the learnings corpus **MAY** enrich what is displayed here; neither may feed a written
     byte except through the founder's confirmation (§19).

8. **Phase 2 dispatch — write confirmed, fresh dispatch.** Inputs: `<type>`, `SEED_ROW`, `SLUG`, the
   normalised `PAGE`, and the founder-confirmed content **verbatim** (inline or via
   `scripts/tmp-dir.sh` temp files by path — **never re-derived**; phase 2 is a fresh dispatch with
   no visibility into phase 1 or the gate). Phase 2 checks out per §18, **re-verifies the
   precondition and both guards as a mandatory TOCTOU backstop** (§18), writes the confirmed content
   to `PAGE` and **only** to `PAGE` — `seed` writes exactly one page for exactly one row, the seed
   instance of §3's "never touches an unaffected row's pages" invariant — regenerates the index +
   `llms.txt` per §19, and commits/pushes/PRs **only if `git status --porcelain` on the written paths
   is non-empty**.

## 17. Seed mode — page artifacts + frontmatter

Each type maps onto an existing `writing-docs` quadrant template via its **registry `quadrant`** —
a lookup, not a new table to maintain:

| `type`              | Registry quadrant | `writing-docs` template | Default `target-path` | File convention | `source:` key                   |
| ------------------- | ----------------- | ----------------------- | --------------------- | --------------- | ------------------------------- |
| `concept`           | explanation       | Explanation             | `docs/concepts/`      | `<SLUG>.md`     | N/A (not a how-to page)         |
| `tutorial`          | tutorial          | Tutorial                | `docs/tutorials/`     | `<SLUG>.md`     | N/A (not a how-to page)         |
| `integration-guide` | how-to            | How-to                  | `docs/integrations/`  | `<SLUG>.md`     | Offered at the gate — see below |
| `how-to`            | how-to            | How-to                  | `docs/how-to/`        | `<SLUG>.md`     | Offered at the gate — see below |

One page per seed run, always a **new** page (§16's page-exists gate). The `target-path` is
`SEED_ROW`'s, not the registry default, and is **trailing-slash-normalised before the join** (§16).

### Page frontmatter (required — `llms.txt` reads it)

Every seeded page **MUST** carry:

```yaml
---
title: <human title for the page>
description: <one line, used verbatim as the llms.txt description>
---
```

**As of NA-61 the `writing-docs` templates emit this frontmatter** — all four Diátaxis templates
(Tutorial, How-to, Reference, Explanation) now carry `title:` + `description:` (bracket-free
`TODO(fill)` scalars the author fills) + `related-adrs: []`. A page authored from a current template
therefore carries the **keys** by construction — but "carries the key" and "is actually filled in"
are different claims, and only the second one satisfies this requirement. The seed layer still
**validates** it at the founder-confirm gate (below) rather than assuming it, because (1) a
**legacy or hand-authored** page — or one written before NA-61 — may still lack the key entirely, and
(2) a current-template page the founder confirmed **without editing** still carries the unfilled
`TODO(fill)` sentinel — present, but not a real title/description. The gate rejects **both**
shapes; the requirement is enforced on the page `seed` writes, not waived by the template's own
scaffolding.

The consequence: §8's `llms.txt` regen derives every entry from the page's frontmatter
(`title — one-line description — relative link`). A seeded page with no frontmatter either **drops
out of `llms.txt` silently** — published but invisible to the index that exists to expose it, the
exact failure `seed` prevents — or makes the regen fail on a page it expects to carry frontmatter. A
seeded page whose frontmatter is **present but still `TODO(fill)`** is **worse**, not merely
equivalent: an absent-frontmatter page is loudly skipped-and-surfaced by §19 below, but a
present-and-unfilled one would satisfy a naive presence check and ship the literal sentinel text into
the public index — silently, and strictly worse than the pre-NA-61 state the skip already handled
loudly. The gate below closes exactly this gap.

**Where the check lives is itself load-bearing:** phase 1 emits the frontmatter; **the command layer
validates it at the founder-confirm gate**, where the content still exists and the founder can fix a
missing line — or an unedited placeholder — in situ. It is **NOT** deferred to phase 2 — a fresh
dispatch holding an opaque payload, which can only STOP, losing a four-hundred-line authored page to
a one-line defect and reintroducing the "STOP after the founder has authored" failure this rule
exists to prevent. Phase 2 MAY keep a defensive assertion, but it **must preserve the content**
(session temp dir + surfaced path) rather
than discard it.

### `source:` frontmatter — `how-to` and `integration-guide` only

Both map onto the how-to quadrant, whose template emits a `source:` glob list. §5 is normative and
unchanged: a how-to page **with** `source:` is auto-refresh-drafted by `sync` when `CHANGED_FILES`
intersects its globs; a page **without** it is **never** auto-refreshed — the deliberate opt-in
boundary. `seed` **is** that founder action, and the natural moment to make the choice:

- The scaffold presents the `source:` list (with the template's explanatory comment) at the gate, and
  the founder supplies globs or removes the key.
- **Founder supplies globs** → the page is written with `source:`; future `sync` runs draft refreshes
  of it. This is the seed → sync handoff that makes `how-to`'s `seed,sync` trigger coherent.
- **Founder omits it** → the key is **omitted entirely** (never written empty). Per §5 the page is
  simply never auto-refreshed. Not an error, and **not something `seed` may infer a value for** —
  inferring globs would opt the founder into automated refreshes of a page they hand-authored.
- `concept` and `tutorial` pages **never** carry `source:` — it is a how-to-quadrant key and §5's
  match semantics apply only to how-to rows. Do not emit it for them.

## 18. Seed mode — branch / PR / control flow

> **Divergence from §7 — do not harmonise.** §7 (`sync`) resets the branch onto regenerated state
> and force-pushes with `--force-with-lease`, safe there because `sync`'s branch content is **fully
> derived**. A seed branch is the opposite extreme: its content is **founder-authored** _and_ the
> control-flow tail drives `/loop /sdlc:loop` against it, so it carries review-fix commits.
> `reset --hard` and force-push are **prohibited** on seed paths.

**All of the precondition and guard rows below are evaluated at [§16 step 5](#16-seed-mode--gate-ladder--page-construction) — before phase 1 dispatches and before the founder authors anything.**
They are defined here and evaluated there. Every input they need (base ref, branch state on `origin`,
the trailer on each commit) is available at step 5; none needs the founder's content. Deferring any
of them to phase 2 would mean a STOP that discards the founder's authored page to protect a condition
knowable before they typed a word. **Phase 2 re-runs them as a mandatory TOCTOU backstop before
writing** (the branch can move while the founder authors), preserving the confirmed content if one
fires.

| Item                      | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Branch                    | `docs/seed-<type>-<SLUG>` (the **normalised** slug — `My Topic` and `my-topic` resolve to the same branch, never two), cut from the **base branch head** (`origin/<BASE-BRANCH>`) — **not** a story branch. A seed authors a new page against current base; there is no story diff to read. Mirrors `refs/adr-pipeline.md`'s §3a `docs/adr-<slug>` shape, with `<type>` included because two types may legitimately seed the same topic (`docs/seed-concept-offline-sync` and `docs/seed-tutorial-offline-sync` are distinct pages and must be distinct branches).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Commit                    | `docs(docs): seed <type> <SLUG>` (via `conventional-commit`), carrying the trailer `Seed-Generated: <type>/<SLUG>`. **The trailer is load-bearing**, not decoration: it is the only reliable marker of "this pipeline wrote this commit", and both guards below key on it. Subject-matching is not a substitute.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR title                  | `docs(docs): seed <type> <SLUG>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Local-branch precondition | Applies on **every** path, first-run and re-run alike, evaluated at §16 step 5. If a **local** `docs/seed-<type>-<SLUG>` exists holding commits not reachable from `origin/docs/seed-<type>-<SLUG>` (or, when no such remote exists, any commits at all beyond `origin/<BASE-BRANCH>`) → **STOP**: `local branch docs/seed-<type>-<SLUG> has unpushed commits; push, drop, or rename it, then re-run.` Never `checkout -B` over it. Hoisted out of the re-run rows deliberately: the first-run path is defined by the branch being absent **on `origin`**, which says nothing about a local branch of the same name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| First-run PR              | No remote branch (`git rev-parse --verify origin/docs/seed-<type>-<SLUG>` fails) → after the precondition passes, create the branch from `origin/<BASE-BRANCH>` head, write, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Re-run behaviour          | **Open or update; the branch's commits are never rewritten.** If the branch exists on `origin` → `git fetch origin`, run the precondition + **both guards at §16 step 5**, then (in phase 2) re-verify them and check it out **at its remote head**: `git checkout -B docs/seed-<type>-<SLUG> origin/docs/seed-<type>-<SLUG>` — **the single normative flow**. Write the confirmed content **on top** as a new commit and `git push` (plain fast-forward). A re-run where nothing changed produces **no commit, no push, no duplicate PR**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Re-run history guard      | The **one forbidden path**: no re-run may reset the branch onto regenerated state, force-push it (`--force` / `--force-with-lease`), or discard any commit reachable from `origin/docs/seed-<type>-<SLUG>`. A reset-to-fresh + `--force-with-lease` would _succeed_ (the local ref was just fetched) and silently revert the PR to unreviewed content. Checking out at the remote head does none of these.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Re-run content guard      | Preserving commits protects **history**; this guard protects **content**. Evaluated at §16 step 5, and **re-verified by phase 2 before writing** — mandatory, because phase 2 is the only layer that writes and the branch can move while the founder authors. Find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path phase 2 writes this run** and **lack the `Seed-Generated: <type>/<SLUG>` trailer**. **That path set is NOT just `PAGE`**: phase 2 also rewrites `llms.txt` (when its row is enabled) and any regenerated section index page — a `/sdlc:loop` review-fix or founder edit to either is exactly the out-of-pipeline content this guard protects, and scoping the scan to `PAGE` alone would silently destroy it with no STOP. If any qualifying path is found → **STOP**: `branch docs/seed-<type>-<SLUG> carries edits to generated pages (<paths>) that this pipeline did not write; re-running would overwrite them — merge or close PR #<n>, or drop those edits, then re-run.` Trailer-bearing commits, and commits touching **other** paths, do not trip it — proceed. |
| Phase-2 TOCTOU re-check   | **MUST, not MAY.** The gate opens an authoring-length window in which the branch can move, and phase 2 is the **only** layer that writes: an optional re-check that an implementer skips would check out at the remote head and write straight over the out-of-pipeline edit the step-5 guard exists to protect, with no STOP. If a re-check STOPs, phase 2 **MUST preserve the confirmed content** — write it to the session temp dir (`scripts/tmp-dir.sh`) and **surface the path in the STOP** — never discard it. A guard that destroys the founder's page while protecting someone else's commit has traded one loss for another. Preservation is what makes a mandatory STOP here costless.                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Control-flow tail         | Mirror §7 / §13 / `refs/adr-pipeline.md`'s §3a: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR (manifest-absent silent no-op, deactivated-type report, founder-declined-at-gate, a usage STOP, a page-exists STOP, or a precondition/guard STOP), release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — only the manifest-absent path is silent. (`seed adr` branches to the ADR pipeline before reaching this generic seed control flow at all — see `commands/docs.md` step 7 — so its own exit paths are not enumerated here.)                                                                                                                                                                                                                                                                                                                                                                                                                 |

### Where edits live, and what a re-run does to them

| Edit made…                                                                                 | Committed by                                                  | A re-run…                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **At the founder-confirm gate** (the founder authors/edits the scaffold before confirming) | phase 2, carrying the `Seed-Generated: <type>/<SLUG>` trailer | **Re-presents a fresh scaffold.** Phase 1 re-scaffolds from the template + topic every run — a prior run's authored prose is **not** carried forward. Not silent (the founder sees exactly what will be written before confirming), but **not preserved either**. |
| **On the branch, outside the pipeline** (a `/sdlc:loop` review-fix commit, a direct push)  | anything **without** the trailer                              | **STOPs — at §16 step 5, before the founder authors.** The re-run content guard refuses to overwrite it and hands the decision back.                                                                                                                              |

The distinction is the **trailer, not the commit subject**. Keying on the subject would be wrong:
phase 2 commits founder gate edits under the normal `docs(docs): seed <type> <SLUG>` subject, so a
subject test classifies them as pipeline-authored and the guard never fires — correct for gate edits
(re-scaffolded by design), but it must not be mistaken for _preserving_ them.

For `seed`, the gate-edit row bites harder than for `release`: a release gate edit is a tweak to
machine-aggregated content, whereas **a seed gate edit is the entire page**. Re-running a seed whose
PR is open therefore means re-authoring. A real UX cost, accepted for v1.

## 19. Seed mode — no-op / change-gate + re-run semantics

### Content purity — the seed variant of the `gh` boundary

§11 established that content written to a file must be a pure function of repo state — `gh`
enrichment feeding written content made output depend on ambient network state and broke idempotence.
**That rule's rationale does not transfer to `seed`, so its form must not be copied blindly.** The
seed rule is:

> **The written page is exactly what the founder confirmed at the gate, byte for byte — never
> re-derived, re-enriched, or re-drafted at write time.**

The founder-confirm gate **is** the purity boundary.

**Scope this rule to content derivation — it is NOT a prohibition on phase 2 touching the network.**
Phase 2 consults no corpus, no `gh`, and no network **for any byte of the page**: it receives the
confirmed content and writes it unchanged. It self-evidently **does** perform the mechanical
git/`gh` operations the write itself requires — `git fetch origin`, `git push`, `gh pr create`, and
the PR number a guard STOP must quote — **because raising the PR is AC4**. An absolute reading
("phase 2 consults no network") would forbid those and silently fail the very AC the phase exists to
satisfy.

This scoping is why `seed` can safely let phase 1 consult ambient sources that `release` must not:

- `refs/doc-types.md` gives `concept` the `source-of-truth` **`learnings corpus`**, and `how-to` /
  `integration-guide` **`founder-authored draft + learnings corpus`** — so phase 1 **may** query
  claude-mem for corpus material to enrich the scaffold for those three types. (`tutorial`'s
  `source-of-truth` is **`founder-authored`** only — **no corpus consultation for it.**)
- `gh` may likewise enrich what is **displayed**.

Both are safe **because** `seed` makes no byte-identity claim (below) and because everything they
touch is a _draft a human reads and rewrites_ before any byte is written. A corpus hit that differs
between runs changes what the founder is _offered_, never what is _written_ behind their back. Were
`seed` ever to gain a "re-derive on re-run" path, this reasoning would have to be re-derived with it
— it is contingent on the gate, not on the sources being trustworthy.

### claude-mem availability — never a halt for `seed`

If the claude-mem MCP tools are unavailable, phase 1 **proceeds without corpus enrichment and says
so at the gate. It does NOT halt.** A deliberate divergence from `distill`, which
`refs/adr-pipeline.md` §5 already draws: _"claude-mem tools absent in distill mode → halt distill …
use seed adr."_ The reason is structural: `distill`'s entire input **is** the corpus, so
without it there is nothing to distill; `seed`'s input is the **founder**, and the corpus is
enrichment. Halting would block a founder from authoring a page they can write unaided.

### Deterministic index + `llms.txt` regen (AC4)

After the confirmed page write, phase 2 deterministically regenerates the doc index and `llms.txt` —
the un-gated half of the run (the same "auto rows are un-gated" discipline `sync` and `release`
apply):

- **`llms.txt`** — **only if the `llms-txt` row is present and enabled in the manifest, checked
  independently of `SEED_ROW`.** `llms-txt` is a `sync`-triggered row; it is **not** the row `seed`
  was invoked for, so its state is **never** inferred from `SEED_ROW`'s activation — a founder may
  perfectly well have `concept` enabled and `llms-txt` declined. Absence is never inferred as enabled:
  a founder who declined `llms-txt` at `/init` (row absent) must never have it written or overwritten
  by a `seed` run. If **disabled or absent**, phase 2 does not write or touch `llms.txt` at all this
  run — any existing file is left exactly as-is. When it **is** enabled: reuse §8's algorithm
  verbatim — index-only, grouping the generated pages of every enabled `public: yes` row by Diátaxis
  quadrant, each entry a `title — one-line description — relative link` derived from page
  frontmatter. The newly seeded page appears in it. Idempotent; committed only if changed.

- **Frontmatter-MISSING-OR-UNFILLED pages the regen encounters are SKIPPED, never fatal, and never
  fabricated.** This story mandates frontmatter on the **page it writes**, and §8's algorithm reads
  frontmatter from **every** enabled `public: yes` page in the tree. As of NA-61 the `writing-docs`
  templates emit `title`/`description`, so a page authored from a current template carries the
  **keys** — **but the regen cannot tell a template-produced page from a legacy one at regen time**
  (there is no origin marker, and an age heuristic would be forbidden ambient input), and it also
  cannot assume the founder-confirm gate (§16 step 7) ran on every page it walks — a page committed
  by some other path, or predating that gate's `TODO(fill)` check, may still carry the scaffold's
  unfilled sentinel untouched. So the trigger for this skip is **"missing `title`/`description` OR
  either still carries the `TODO(fill)` sentinel"** — not presence alone. It stays **universal**; it
  simply fires **rarely** now — only for a legacy/hand-authored page (or one predating NA-61) that
  lacks frontmatter, or an unedited scaffold that slipped past the gate. Do not remove it: legacy
  pages still depend on it. That exposure is pre-existing and shared with `sync`/`release`; `seed`
  merely walks into it.
  - A page missing, or still carrying the `TODO(fill)` sentinel in, `title`/`description` is
    **omitted from `llms.txt`** and its path **surfaced in the phase-2 output and the PR body**.
    Loud, not silent — this is the invariant the seed founder-confirm gate's own `TODO(fill)` check
    (§17) exists to make rare, not the invariant that makes that gate check optional: the gate is the
    fast, in-context catch; this skip is the regen-time backstop for anything that reaches it anyway.
  - It is **never a STOP.** A STOP mid-phase-2 would **tear the write** — the founder's page
    committed, the index not — and would let an unrelated page's defect block a valid seed the
    founder just authored.
  - Its `title`/`description` are **never** inferred from the body or filename, and an unfilled
    sentinel is **never** silently treated as "present enough" to ship. Both would fabricate or leak
    unintended text into published index copy, the fabrication boundary this pipeline holds
    everywhere else.

- **The doc index** — if the consumer's docs tree already carries a section index page at
  `SEED_ROW`'s `target-path`, regenerate it deterministically (**upsert** the page's entry — add if
  absent, rewrite in place if present; never append a duplicate). If none exists, `llms.txt` is the
  sole index and **no separate section index is created**. No new index file type is invented.

  **The "already carries a section index" test is evaluated against the PRE-write tree state** — the
  branch/base head as fetched — **never the post-write working tree.** Otherwise a page this run just
  wrote can satisfy the regen's own precondition and be rewritten as a generated index inside the
  same commit: exactly the `seed <type> index` self-destruction §15's reserved-page-id STOP closes
  from the other side. **Both rules are required; neither is redundant.**

- **All four seed types are `public: yes`** in the registry, so a seeded page always belongs in
  `llms.txt` when that row is enabled. (`adr` is the registry's only `public: no` row — handled by
  the special `seed adr` route to `refs/adr-pipeline.md`, not the generic seed machinery.)

### No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** See
  [§1's Manifest gate](#manifest-gate-shared-by-sync-release-seed-and-audit) — the base-ref pre-check is
  ordered **before** the absence conclusion. No prompt, no branch, no dispatch, no PR, no error, **no
  stdout**, exit 0.
- **Deactivated type → informational report, no write (AC2)** (§16 step 3). Distinct from the silent
  no-op: the manifest exists, so the founder opted in.
- **Founder rejects at the gate → nothing written**, no branch, no PR, no phase-2 dispatch; report
  and exit cleanly. There is no deterministic half worth committing: the index/`llms.txt` regen is a
  _consequence_ of the page write, so with no page there is nothing to reindex.
- **Commit/PR only on actual content change (AC4).** Phase 2 commits only if `git status --porcelain`
  on the written paths is non-empty.
- **`llms.txt` regenerated only when its own manifest row is present and enabled**, committed only if
  changed.

### Re-run semantics — what is and is not deterministic

**`seed` makes NO byte-identity claim for a seeded page body, and this ref will not imply one.**
§14's idempotence contract ("same range + same confirmed content → same bytes") is a statement about
a **generator** whose input is repo state. `seed`'s page body has no such input: it is founder prose
typed at a gate. Re-running `seed concept offline-sync` re-prompts and re-authors; asserting
byte-identity would be false. **Do not copy §14's idempotence wording.**

| Property                                        | Holds?  | Scope / why                                                                                                                                                     |
| ----------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Page **identity** is stable across re-runs      | **Yes** | `SLUG` normalisation — one branch, one PR, one page id per topic, regardless of how the topic was typed                                                         |
| Page **body** is byte-identical across re-runs  | **No**  | It is founder-authored input, re-authored at each run's gate. No claim is made                                                                                  |
| **Write-time fidelity**                         | **Yes** | Phase 2 writes the confirmed content **verbatim** — the bytes written are the bytes the founder saw. **This, not byte-identity, is `seed`'s content guarantee** |
| **`llms.txt` / index regen** is deterministic   | **Yes** | Pure function of the enabled `public: yes` rows' page frontmatter (§8). Re-running over an unchanged page set yields byte-identical output                      |
| **Commit/PR only on actual content change**     | **Yes** | Phase 2 commits only if `git status --porcelain` on the written paths is non-empty                                                                              |
| Branch commits are **preserved** across re-runs | **Yes** | Never reset, never force-pushed — §18                                                                                                                           |

## 20. Audit mode — scan scope + two-tier drift model

`audit` is the **comprehensive** pass: unlike `sync` (branch-diff-scoped) and `release`/`seed`
(verb-triggered), a default run scans **every row activated in the manifest** — present **and**
`enabled = true` (the same "absent is never activated" rule §16 states; never infer a missing row
as active), **regardless of which mode generates it**. `audit` is **not** keyed on the registry
`trigger` column — **no row carries `audit` in its trigger, and none should.**

**The activated set partitions into exactly two tiers, keyed solely on `generation-mode` — never a
hand-list:**

| Tier                          | Membership                                                                   | Drift means                                                                                                                                                                         | Action                                                  |
| ----------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **Deterministic** (§21)       | every activated row with `generation-mode = auto`                            | published page ≠ byte-deterministic regen of source-of-truth                                                                                                                        | **correct** — the regenerated bytes, committed un-gated |
| **Reference-integrity** (§22) | every activated row with `generation-mode ∈ {draft-for-review, manual-only}` | a **verifiable anchor** the page declares has moved — including a `.md`/`.mdx` doc link that does not resolve file-relative from the page's own directory (the dangling-link check) | **flag** in the report — **never rewrite the prose**    |

There is **no third bucket and no "unclassified" row**. An `auto` row is deterministic; **every**
non-`auto` row is reference-integrity — **`changelog` (draft-for-review) included**, so published
changelog drift is never left unscanned (AC1). Resolved against `refs/doc-types.md` today the full
`auto` row set is `command-reference`, `agent-reference`, `skill-reference`, `hooks-contract`,
`api-reference`, `schema-reference`, `config-reference`, `cli-reference`, `error-reference`, and
`llms-txt` — but the reference-family members of that set are also **activation-gated** (§3's
activation note): only the subset **activated** in the consumer manifest is actually scanned, never
the full registry list. Reference-integrity = `changelog`, `release-notes`, `migration-guide`,
`tutorial`, `how-to`, `integration-guide`, `concept`. **Both enumerations are illustrative
snapshots, not the source of truth — derive tier membership from `generation-mode` at read time,
and derive live membership from each row's `applies-when` activation at read time.** Building the
scan from a copied row list reintroduces the `changelog`-omission defect (the hardcoded-list drift
class NA-54 hit); scanning an inactive reference row would reintroduce the empty-page defect this
story (NA-65) exists to close.

Row activation is resolved from the manifest **checkout-independently** at `origin/<BASE-BRANCH>`
(the [manifest gate](#manifest-gate-shared-by-sync-release-seed-and-audit) already fetched and
validated the base ref). `refs/doc-types.md` **unreadable or malformed → surface and STOP** — never
audit against a partial registry, and never fall back to a hardcoded row list (the discipline
`seed`'s `SEED_TYPES` resolution applies).

## 21. Audit mode — deterministic-correction set

For each activated row whose `generation-mode` is `auto`, reuse **§3's deterministic regen
procedure** to regenerate the row's pages from **current** source-of-truth at `origin/<BASE-BRANCH>`,
then compare the regenerated bytes against the **published** page at the same base ref
(checkout-independently — never the working tree, for the reason every sibling reads that way):

- **A non-empty diff IS drift**, provably — the published page is not what its source-of-truth would
  currently generate. **The correction is the regenerated bytes.** No semantic judgment is involved.
- **Affectedness keying does not apply.** §3's "affected when `CHANGED_FILES` contains …" columns are
  a `sync`-only optimisation over a branch diff. `audit` has no branch diff: it treats **every**
  activated `auto` row as in-scope and regenerates it unconditionally. `audit` reuses §3's per-row
  _regeneration procedure_, not its _affectedness keying_.
- **`llms.txt` is an `auto` row and is regenerated like the others** (§8's format) — and its regen
  reflects any pages this run corrected (see §24).
- **Frontmatter-missing-or-unfilled-page handling is §19's, verbatim.** A pre-existing `public: yes`
  page lacking `title`/`description`, **or still carrying the `TODO(fill)` sentinel in either**, that
  surfaces during the `llms.txt` regen is **skipped and surfaced, never a STOP, never inferred** —
  `audit` adopts §19's skip-and-surface rule (missing OR unfilled) and does not invent a new one, nor
  STOP the whole audit over one such page.

Every deterministic correction is a pure function of source-of-truth (byte-reproducible), which is
what lets it be committed **un-gated** — the same "auto rows are un-gated" discipline `sync`,
`release`, and `seed` apply. **No ambient input** (`gh`, network) may feed a byte of it.

## 22. Audit mode — reference-integrity flagging + AC4 ADR-direction rule

For each activated **narrative** row (`generation-mode ∈ {draft-for-review, manual-only}` — which
includes `changelog`, `release-notes`, `migration-guide`, `tutorial`, `how-to`, `integration-guide`,
`concept`), `audit` **does not re-judge the prose and does not rewrite it.** It checks only
**verifiable anchors the page itself declares**, each a deterministic git/filesystem signal, and
**flags** (never corrects) a hit:

- **`source:`-glob drift (`how-to`, `integration-guide`).** A page carrying `source:` frontmatter
  (§5) whose globbed source files have commits **newer than the page's own last commit** is flagged
  as potentially stale — the same signal `sync` uses to draft a refresh, but surfacing pages `sync`'s
  branch-scoping never reached. A `source:`-less page is **not** flagged (§5's opt-in boundary).
- **Referenced-ADR drift (AC4).** A page that **declares an ADR reference** — an inline link to
  `docs/adr/NNNN-*` **or a non-empty `related-adrs:` frontmatter key** (a YAML list of
  repo-root-relative `docs/adr/NNNN-*.md` paths, resolved **identically** to the inline-link form —
  audit needs no number→file mapping) — whose referenced ADR has commits newer than the page is
  flagged **as "the doc diverges from the ADR"**. The ADR is source of truth; **the direction is
  fixed and `audit` never proposes the reverse.** It reads `docs/adr/**` **read-only** and **never
  writes `docs/adr/`** (the `adr` row is `public: no` — `audit` is a _public-docs_ accuracy tool). A
  page with **no** declared ADR reference is **never attributed** to an ADR — the association is
  never fabricated.

  **Reliability caveat (OR-semantics — empty ≠ "no ADR").** As of NA-61 all four `writing-docs`
  templates emit a `related-adrs:` key, defaulting to `[]`. The flag is an **OR** over two arms: it
  fires for a page that **opted in** — an inline `docs/adr/…` link **OR** a **non-empty**
  `related-adrs:`. A template-produced page left at the empty `[]` default is **not** flagged via the
  key (it opted out) — an empty/absent `related-adrs:` means "the frontmatter arm is silent," so audit
  **falls through to the inline-link arm**; it never means "this page has no ADR." A page carrying an
  inline `docs/adr/…` link but a default-empty key therefore **keeps** the detection it had before
  NA-61 (no regression). Do **not** read this as "the flag is now reliable for every template page" —
  a page at the `[]` default is not audited via the key.

- **Dangling code reference.** A page referencing a repo-relative code path that no longer exists at
  the base ref is flagged. Deterministic (path-existence check), never a semantic guess.
- **Dangling `related-adrs:` path.** A `docs/adr/…` path listed in `related-adrs:` that does **not**
  resolve to an existing `docs/adr/*.md` file at the base ref is flagged as **dangling** — a
  path-existence check (the same primitive as the dangling code-reference check above, extended to the
  ADR arm). This is **distinct** from the newer-commits drift check: a non-existent ADR has **no**
  commits, so the drift check (`git log` on the path → empty) **silently passes**; without this
  separate existence check a typo'd or deleted `docs/adr/` path would permanently advertise a phantom
  ADR audit never catches.
- **Dangling doc-to-doc link.** An internal Markdown link whose target ends in `.md`/`.mdx` is flagged
  when it does **not** resolve **file-relative from the linking page's own directory** at the base ref —
  the same resolution a static-site build applies, and the same primitive as the two dangling checks
  above, extended to the narrative prose's own doc-to-doc links. **External** links (`http://`,
  `https://`, protocol-relative `//`), **`mailto:`**, and **pure-anchor** links (`#section`, no path
  component) are skipped outright — they are never doc-to-doc targets. A fragment on a doc link
  (`page.md#section`) is **stripped before resolving**; only the file's existence is checked, never
  whether the fragment itself exists on the target page. Deterministic (path existence), never a
  link-quality or SEO judgment, and flagged exactly like its siblings — never rewritten or
  auto-corrected. This is the check that catches a link authored `docs/foo.md` from a page already
  inside `docs/` (needs `foo.md` or `../foo.md` instead) — the target usually still exists somewhere in
  the repo, just not at the resolved path, so no other check in this tier would catch it.

**No narrative `title`/`description` presence flag (re-homed from §24).** `audit` does **not** add a
flag for a narrative page that lacks `title`/`description` frontmatter. Even though NA-61's templates
now emit both, the regen cannot distinguish a template-produced page from a legacy one, so such a
flag would fire on nearly every legacy/hand-authored page — a **template-source defect, not per-page
drift**. Frontmatter-less pages are handled by §19's skip-and-surface, **not** by a drift flag. (This
decision was previously recorded in §24's OQ carry-over; it is re-homed here so it is not lost when
that now-resolved carry-over is retired.)

**Pure narrative divergence with no verifiable anchor is deliberately NOT audited in v1** — detecting
that hand-authored prose has semantically drifted from an ADR requires an LLM judgment that is
neither deterministic nor reproducible, and acting on it would be fabrication. `audit`'s narrative
tier reports only anchor-backed signals, and says so.

## 23. Audit mode — findings report + `--dry-run`

The findings report is a structured, deterministic Markdown enumeration, grouped into the two tiers,
one entry per finding:

```text
<row-type> · <page path> · <drift kind> · <evidence>
```

e.g. `command-reference · docs/reference/commands/docs.md · regen-diff · 3 lines differ from the
current frontmatter-derived page`; `concept · docs/concepts/offline-sync.md · adr-drift ·
docs/adr/0007-*.md changed 2 commits after page`; `how-to · docs/how-to/deploy-preview.md ·
dangling-link · docs/setup.md does not resolve file-relative from docs/how-to/`. It is emitted to
stdout in **both** modes; in default mode it is
embedded verbatim in the PR body so a reviewer sees every flag — including narrative flags `audit`
did **not** auto-correct — alongside the committed corrections.

- **`--dry-run`:** the dispatch returns the report; the command **prints it to stdout** and opens
  **no** PR, writes nothing (AC3). A clean scan prints the one-liner `docs are in sync — no drift
found`. `--dry-run` **always ends before any PR** and releases via `session-complete.sh`.
- **default:** see §24 for the write/PR-on-change path.

**Determinism scope (load-bearing).** The **deterministic-correction set** (`auto`-row regenerated
pages + `llms.txt`) is a pure function of source-of-truth at the base ref: re-running over an
unchanged repo yields the **byte-identical** correction set, so a re-run with no new drift commits
nothing and opens no PR. `audit` makes **no** determinism claim about the reference-integrity flags'
phrasing or completeness (deterministic _inputs_, human-facing prose _findings_), and **no** claim of
detecting semantic narrative drift at all. State only the determinism that holds (the NA-53/54
lesson).

## 24. Audit mode — branch / PR / control flow + no-op semantics

> **Adopts the release/seed model, not §7's sync reset.** `audit`'s corrections are fully derived,
> but — like `release`/`seed` — the control-flow tail drives `/loop /sdlc:loop` against the PR, so
> the branch carries review-fix commits. `reset --hard` and force-push are **prohibited** on audit
> paths.

| Item                      | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branch                    | `docs/audit-<YYYY-MM-DD>`, cut from `origin/<BASE-BRANCH>` head — mirrors `refs/adr-pipeline.md`'s §3a `docs/adr-distill-<YYYY-MM-DD>` dated-branch convention for a periodic scan (a same-day re-run open-or-updates the same branch/PR). The date forms the **branch name only** — it never feeds a written byte, so it does not compromise the determinism claim (§23).                                                                                                 |
| Commit / PR title         | `docs(docs): audit <YYYY-MM-DD>` (via `conventional-commit`), carrying the trailer `Audit-Generated: <YYYY-MM-DD>` — **load-bearing**, keyed on by both re-run guards.                                                                                                                                                                                                                                                                                                     |
| PR base                   | `<BASE-BRANCH>` from project-context (never assume `main`).                                                                                                                                                                                                                                                                                                                                                                                                                |
| Local-branch precondition | Adopted from §13/§18: a **local** `docs/audit-<DATE>` holding unpushed commits → **STOP**; never `checkout -B` over it.                                                                                                                                                                                                                                                                                                                                                    |
| Re-run behaviour          | Open-or-update; the branch's commits are never rewritten. If it exists on `origin` → `git fetch`, run both guards, check out at its remote head (`git checkout -B docs/audit-<DATE> origin/docs/audit-<DATE>`), write the fresh corrections on top, plain fast-forward `git push`.                                                                                                                                                                                         |
| Re-run history guard      | No re-run may reset onto regenerated state, force-push, or discard any commit reachable from `origin/docs/audit-<DATE>`.                                                                                                                                                                                                                                                                                                                                                   |
| Re-run content guard      | Find commits on the branch (relative to `origin/<BASE-BRANCH>`) that touch **any path this run writes** and **lack the `Audit-Generated:` trailer** → **STOP** and quote the paths + PR number. **The scanned path set is every path this run writes** — the corrected `auto`-row pages **plus** `llms.txt` — never a narrower set.                                                                                                                                        |
| Write + PR only on change | Commit and open-or-update the PR **only if `git status --porcelain` on the written paths is non-empty**; otherwise no commit, no PR, report clean (AC2).                                                                                                                                                                                                                                                                                                                   |
| Control-flow tail         | After a PR is raised, drive `/loop /sdlc:loop <PR_URL>` (fallback `ScheduleWakeup`), exactly as the three siblings. If the run ended **before** any PR — manifest-absent silent no-op, a clean scan, a reference-integrity-flags-only scan, a usage STOP, or a precondition/guard STOP — release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh`. Only the manifest-absent path is silent. **`--dry-run` always ends before a PR** and releases this way. |

### No-op / report-only semantics

- **Manifest absent** → **silent** no-op: no scan, no dispatch, no PR, no error, **no stdout**, exit
  0 (AC5) — for **both** `audit` and `audit --dry-run`. The base-ref pre-check
  ([§1's gate](#manifest-gate-shared-by-sync-release-seed-and-audit)) runs **first**, so a
  `git fetch` / unresolvable-`origin/<BASE-BRANCH>` failure is a **STOP**, never mistaken for absence.
- **Manifest present, no row activated** → clean scan, report `no activated doc types to audit`, no
  PR. **Informational, not silent** (the manifest exists).
- **default, ≥1 deterministic correction** → write the regenerated `auto` pages, embed the full
  findings report (corrections **and** reference-integrity flags) in the PR body, open-or-update the
  PR (AC2).
- **default, drift is ONLY reference-integrity flags** (no deterministic correction to commit) →
  report the flags to stdout, open **no** PR — there is nothing mechanical to commit and fabricating
  a narrative fix is forbidden. **(OQ, §Open-Questions in the spec: stdout report, no PR, for v1.)**
- **default, no drift of either tier** → report clean, open nothing (AC2).

### Frontmatter-in-templates (resolved by NA-61)

NA-61 landed: all four `writing-docs` templates now emit `title:` + `description:` +
`related-adrs:`. The two former carry-overs are resolved and homed elsewhere — the `llms.txt`
frontmatter-less-page handling is §19's (now-rare, still-universal) skip-and-surface, and the decision
**not** to add a narrative `title`/`description` presence flag is recorded in §22. Nothing further is
carried here.

## 25. Post-QA inline dispatch variant

`sync` composes into a run that **already owns** a story branch + one PR — the Principal Engineer
playbook's **Step 6.5**, fired after QA returns `clean` and before the PR is opened. Standalone
`sync` (§7) is **wrong** for that context: it cuts its own `docs/sync-<KEY>` branch, runs a
founder-confirm gate, and raises its own PR. This **inline post-QA variant** keeps the regen but
strips the standalone control flow. Its **four** divergences from standalone `sync`, each with the
reason it exists:

1. **No `docs/sync-<KEY>` branch — writes on the story branch in `$WORKTREE`.** The orchestrator
   hands the agent the live `$WORKTREE` (checked out at `<BRANCH_PREFIX>/<STORY-KEY>`) and
   `$NX_CACHE_DIRECTORY`, exactly as Step 4 / QA-Step-3 domain dispatches do. The agent does **not**
   check out or cut any branch. _Reason:_ docs must land on the impl branch (AC2); a separate branch
   would need a separate PR.
2. **Single dispatch, no founder-confirm gate.** The two-phase compute→gate→write split (§2) exists
   only to host the founder-confirm gate across a dispatch boundary. AC2 removes that gate — PR
   review is the sign-off — so the variant is a **single dispatch** that computes **and** writes the
   deterministic regen + `llms.txt` **and** the narrative how-to refreshes in one pass. The how-to
   drafts are written un-gated and reviewed in the impl PR. _Reason:_ a dispatched subagent cannot
   pause for interactive input; with the gate removed there is nothing to split across, and the
   human review moves to the PR.
3. **Commit-only; the orchestrator pushes.** The agent commits the docs changes via
   `conventional-commit` onto `<BRANCH_PREFIX>/<STORY-KEY>` and returns; the orchestrator pushes and
   runs the same push / primary-checkout guard as playbook Step 5. _Reason:_ matches the
   `domain-agent-handoff.md` "agent commits, orchestrator pushes" contract every in-playbook
   dispatch obeys — the agent's self-raise-PR behaviour applies only to **standalone**
   `/sdlc:docs`.
4. **Raises no PR.** Step 7 folds the docs commit into the impl PR. _Reason:_ AC2.

**Diff source handed in, not resolved here.** The playbook passes the **story-branch-vs-base** source
explicitly — `origin/<BASE-BRANCH>...<BRANCH_PREFIX>/<STORY-KEY>` (§26) — because at Step 6.5 the
branch always exists. The variant never runs §26's merged-commit selection.

**Everything else is §§1–6, verbatim.** The deterministic regen algorithm (§3), the `source:` how-to
convention (§5), the affected-row resolution (§3), the manifest gate (§1), and the change-gate
(commit only if `git status --porcelain` on the written target paths is non-empty, §6) are
**unchanged** — the variant reuses them and never restates them. A no-source-change re-run commits
nothing. The failure classification (which failures WARN vs STOP) is a **playbook-layer** decision —
see `refs/principal-engineer-playbook.md` Step 6.5; this ref defines only the dispatch shape.

## 26. Dual diff source + selection rule

`sync` derives `CHANGED_FILES` / `CHANGED_DIFF` from one of **two** sources, so it works both before
and after the story branch merges:

| Diff source                                | `CHANGED_FILES` / `CHANGED_DIFF` derivation                                                                                               | Used when                                                                                                                                                                            |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **story-branch-vs-base** (existing, NA-52) | `git diff [--name-only] "origin/<BASE-BRANCH>...$STORY_BRANCH"` — three-dot range, remote-tracking base, after `git fetch origin --quiet` | The story branch **exists on origin** (`origin/feat/<STORY-KEY>` or `origin/fix/<STORY-KEY>`). The **post-QA phase (§25) always selects this** — the branch is present and unmerged. |
| **merged-commit** (NEW, this story)        | Locate the commit(s) on `origin/<BASE-BRANCH>` carrying `<STORY-KEY>`, then `git diff [--name-only] "<sha>^..<sha>"` (see below)          | The story branch is **absent on origin** — a post-merge (squash-merged, branch deleted) or never-branched standalone `sync`.                                                         |

### Selection rule (deterministic, no ambient input)

1. Resolve `STORY_BRANCH` (§2 step 2 / `commands/docs.md` step 2): `origin/feat/<STORY-KEY>`
   preferred, `origin/fix/<STORY-KEY>` fallback.
2. **`STORY_BRANCH` resolved** → **story-branch-vs-base** source (unchanged v1 behaviour).
3. **Neither branch exists on origin** → **merged-commit** source (this replaces the former
   WARNING-and-exit stub).

The **post-QA phase (§25)** never reaches step 3 — it passes story-branch-vs-base explicitly.

### Merged-commit source — precise definition

The story branch is gone, so the diff comes from the landed commit(s) on base:

1. **Locate** the commit(s) on `origin/<BASE-BRANCH>` whose subject **or** body carries
   `<STORY-KEY>`, using the **`PROJECT_KEYS`-scoped alternation regex** from
   [§10's Story-key extraction](#story-key-extraction) (`\b(?:KEY1|KEY2|…)-[0-9]+\b`) — **never** the
   loose `[A-Z][A-Z0-9]*-[0-9]+` matcher (it false-positives on `UTF-8`, `SHA-1`, per §10). Scan
   `git log origin/<BASE-BRANCH>` after `git fetch origin --quiet`.
2. **Diff derivation.** This repo squash-merges (`gh pr merge --squash`), so a story lands as a
   **single** commit with **one** parent: `CHANGED_FILES=$(git diff --name-only "<sha>^..<sha>")`,
   `CHANGED_DIFF=$(git diff "<sha>^..<sha>")`. For a true merge commit (two parents) use the
   first-parent form `"<sha>^1..<sha>"`.
3. **Zero commits match** `<STORY-KEY>` on base → **STOP with an explicit error**
   (`cannot locate a merged commit for <STORY-KEY> on origin/<BASE-BRANCH> — nothing to diff`),
   never a silent no-op. "The branch is gone AND no landed commit references the key" is a real
   failure and must be visible, not collapsed into the benign "docs already current" path.
4. **Multiple commits match** (the story landed across several merges — e.g. a follow-up fix) → diff
   the **union** of each matching commit's `<sha>^..<sha>` file/hunk set, mirroring §10's
   "de-duplicated union across records".

`git fetch` failure, or an unresolvable `origin/<BASE-BRANCH>`, is a **STOP** on this path — exactly
as the shared manifest gate (§1's base-ref pre-check) already requires; never a fallthrough to
"no diff".

> **Underspecified — decision recorded (Open Question #1, adopted).** The spec flags the
> multiple-merged-commits case as the one genuinely ambiguous sub-point. The adopted default (above)
> is the **union** of each matching commit's `<sha>^..<sha>` set, mirroring §10's union discipline —
> deterministic and complete. The alternative (most-recent commit only) risks missing files an
> earlier commit changed. If a reviewer prefers most-recent-only, change §26 step 4 and note it.
