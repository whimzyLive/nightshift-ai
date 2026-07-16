# PRD — Public docs generation via `/sdlc:docs` command + knowledge-engineer

- **Epic:** NA-50
- **Date:** 2026-07-17
- **Status:** Ready for spec
- **Source of truth:** NA-50 Epic description (full agreed design)
- **Roles affected:** Founder / solo dev running the sdlc pipeline; downstream plugin-consumer repos that ship a public product
- **Surfaces:** CLI plugin (the `sdlc` Claude Code plugin — commands, refs, agents). Mobile / offline: N/A.

---

## Problem Statement

The `sdlc` plugin automates the "knowledge in" side of building software — idea to spec to plan to
implementation to review to PR — and NA-43 added the knowledge-engineer agent and `/sdlc:adr` command
to capture architectural learnings as they accrue. But nothing automates the "knowledge out" side:
public-facing technical documentation. The moment code ships, the founder has to stop building and
hand-write reference docs, changelogs, tutorials, and integration guides. That work is manual, easy to
skip, and — because it is written after the fact — drifts out of sync with the product almost
immediately. Reference docs describe an API that has since changed; the changelog misses merged
stories; tutorials rot. A solo founder cannot keep public docs continuously accurate by hand while
also shipping features.

Separately, `/sdlc:adr` sits as its own command with its own founder-confirm gate, even though ADRs are
just one kind of document. As the plugin grows more doc types, one command per doc type does not scale —
the natural unit is the *trigger moment* (something shipped, a release cut, the founder authored a
note), not the doc type.

## Solution

A single umbrella `/sdlc:docs` command that generates public technical documentation continuously, at
the trigger moments where docs should change. The guiding principle: **commands map to trigger moments
(verbs), not doc types**. Doc types are data in a registry; triggers are the verbs that regenerate them.

`/sdlc:docs` ships five modes, each keyed to a trigger moment:

- **`sync <STORY-KEY>`** — post-merge or on a story branch: diff-driven regeneration of reference docs
  plus how-to drafts for what that story changed.
- **`release <version>`** — aggregate merged stories since the last tag into a changelog, release
  notes, and a migration guide stub; release notes link the motivating ADRs.
- **`seed <type> [topic]`** — the founder authors a doc inline (mirrors the old `/sdlc:adr seed`).
  ADR seeding rides the same signature: `seed adr <pattern>` — ADR is just a doc type.
- **`audit [--dry-run]`** — staleness / drift scan of docs vs. accepted ADRs and code; opens a PR only
  on findings.
- **`distill`** — distill the accumulated learnings corpus into promotable ADR candidates (absorbed
  from the old `/sdlc:adr distill`).

The work is done by the **existing knowledge-engineer agent** (no new agent), which already owns the
knowledge lifecycle, ADR index read paths, and mem-search tools. A new `refs/docs-pipeline.md` mirrors
the shape of the shipped `refs/adr-pipeline.md`: draft → propose → founder-confirm gate at the command
layer → write MDX → regenerate index + `llms.txt` → commit/PR.

Hallucination risk is controlled **per doc type**. Frontmatter-driven reference docs (command / agent /
skill / config reference, hooks contract, error reference) and `llms.txt` are **deterministic auto-gen**
like the ADR index. Narrative types (tutorials, how-to recipes, integration guides, concepts) are
**draft-for-review behind a gate**. Concepts and architecture derive from ADRs — ADRs are never
published verbatim.

Doc types are declared in a plugin-shipped, Diataxis-based taxonomy (`refs/doc-types.md`). Each repo
activates the rows and target paths it wants via `.claude/project/docs-manifest.md`, scaffolded by
`/sdlc:init` as an **opt-in** prompt. Repos that decline get **silent no-op** behaviour from every docs
feature — zero setup cost, no surprise output.

Finally, `/sdlc:adr` is **absorbed** into `/sdlc:docs`: the standalone command is removed, ADR becomes a
registry row targeting `docs/adr/`, and the reused `refs/adr-pipeline.md` is invoked by `/sdlc:docs` for
the adr type with the founder-confirm gate moved to the docs command layer.

## User Story

**As a** founder / solo dev shipping a public product with the `sdlc` plugin,
**I want** a single `/sdlc:docs` command that regenerates the right public documentation at each trigger
moment — deterministically where it can, as gated drafts where it must — and that keeps `/sdlc:init`,
the release flow, and the post-QA implementation flow wired into it,
**So that** my public docs stay continuously accurate as code ships, without me hand-writing and
re-syncing them after the fact and without risking hallucinated reference content.

## Acceptance Criteria

Binary, testable:

1. A single `/sdlc:docs` command exists with exactly five modes — `sync`, `release`, `seed`, `audit`,
   `distill` — each dispatching the knowledge-engineer agent; no per-doc-type command is added.
2. `refs/docs-pipeline.md` exists and defines the pipeline stages draft → propose → founder-confirm
   (at the command layer) → write MDX → regenerate index + `llms.txt` → commit/PR, mirroring
   `refs/adr-pipeline.md` (copied shape, not abstracted into a shared ref).
3. A plugin-shipped `refs/doc-types.md` registry defines each doc type with its Diataxis quadrant,
   trigger, source-of-truth, generation mode (`auto` | `draft-for-review` | `manual-only`), and target
   path; ADR is present as an internal row targeting `docs/adr/` marked never-published-to-public.
4. `/sdlc:init` offers an **opt-in** prompt to scaffold `.claude/project/docs-manifest.md`; re-running
   init on an existing repo offers to add the manifest via the normal merge/confirm flow.
5. In a repo with **no** `docs-manifest.md`, every `/sdlc:docs` mode and every docs hook is a **silent
   no-op** (no output, no PR, no error).
6. `sync <STORY-KEY>` regenerates frontmatter-driven reference docs **deterministically** (auto, no
   gate) and produces how-to drafts **behind the founder-confirm gate**; it regenerates `llms.txt`
   deterministically as part of the run.
7. `release <version>` aggregates stories merged since the last tag into a changelog, release notes
   (with links to motivating ADRs), and a migration-guide stub.
8. `audit` scans public docs against accepted ADRs and code and opens a PR **only** when it finds
   drift; `audit --dry-run` reports findings and opens no PR; a clean audit opens nothing.
9. `seed adr <pattern>` and `distill` invoke the retained `refs/adr-pipeline.md`; the standalone
   `/sdlc:adr` command is **removed** and all NA-43-era references to it are updated to the
   `/sdlc:docs` equivalents.
10. The principal-engineer playbook runs a post-QA docs phase: after a clean QA verdict in both
    `/sdlc:impl` and `/sdlc:auto`, it dispatches `knowledge-engineer docs sync <KEY>` inline on the
    story branch; docs commits land on the same branch/PR, PR review substitutes for the founder-confirm
    gate, and the phase no-ops when no `docs-manifest.md` is present.

## User Flows

### Mode: `sync <STORY-KEY>` (manual invocation, repo has a manifest)

Happy path:
1. Founder runs `/sdlc:docs sync NA-XX` on a story branch or after merge.
2. Command reads `docs-manifest.md`; resolves the active doc-type rows and their target paths.
3. Command computes the diff for the story (see dual diff-source below) and dispatches
   knowledge-engineer.
4. For each **auto** reference row affected, the agent regenerates the doc deterministically from
   frontmatter/source; regenerates `llms.txt`.
5. For each **draft-for-review** how-to row affected, the agent drafts content and holds it at the
   founder-confirm gate at the command layer.
6. Founder confirms/edits drafts; command writes MDX, commits, opens/updates a PR.

Edge cases:
- **No manifest** → silent no-op; command exits without output.
- **No doc-type row is affected by the diff** → no drafts, deterministic `llms.txt` regen only (or
  nothing if unaffected); no PR if there is no change.
- **Draft rejected at the gate** → that draft is discarded; deterministic reference regen still lands.
- **Dual diff-source:** sync must support both `story-branch-vs-develop` (pre-merge, on branch) and
  `merged-commit` (post-merge) as the diff source; the mode selects the correct source for the context.

### Mode: `release <version>`

Happy path:
1. Founder runs `/sdlc:docs release 1.4.0`.
2. Command aggregates all stories merged since the last tag.
3. knowledge-engineer generates: changelog entry, release notes (linking the motivating ADRs per
   story), and a migration-guide stub.
4. Narrative pieces pass the founder-confirm gate; deterministic index/`llms.txt` regen runs; commit/PR.

Edge cases:
- **No manifest** → silent no-op.
- **No stories merged since last tag** → nothing to aggregate; no PR.
- **A merged story has no motivating ADR** → release note omits the ADR link rather than fabricating one.
- **Migration-guide stub depth** is scaffold/headings by default (see Open Questions).

### Mode: `seed <type> [topic]` (incl. `seed adr`)

Happy path (general doc type):
1. Founder runs `/sdlc:docs seed concept "background jobs model"`.
2. Command confirms the type is a `manual-only` / `draft-for-review` row in the manifest.
3. knowledge-engineer scaffolds the doc; founder authors inline; founder-confirm gate; write MDX;
   regen index + `llms.txt`; commit/PR.

Happy path (`seed adr <pattern>`):
1. Founder runs `/sdlc:docs seed adr "prefer composition over inheritance in reducers"`.
2. Command routes the adr type to the retained `refs/adr-pipeline.md` (reused as-is).
3. Founder-confirm gate now lives at the `/sdlc:docs` command layer; ADR is written to `docs/adr/`,
   ADR index regenerated deterministically; commit/PR. The ADR is **not** published to public docs.

Edge cases:
- **No manifest** → silent no-op.
- **Type not in the manifest** → command reports the type is not activated; no write.

### Mode: `audit [--dry-run]`

Happy path:
1. Founder runs `/sdlc:docs audit`.
2. knowledge-engineer scans public docs against accepted ADRs and current code for staleness/drift.
3. **Findings** → opens a PR with the corrections. **No findings** → opens nothing and reports clean.
4. `--dry-run` → reports findings but opens no PR.

Edge cases:
- **No manifest** → silent no-op.
- **Drift found only in ADR-derived concept docs** → audit flags divergence from the accepted ADR
  (source of truth), not the reverse.

### Mode: `distill`

Happy path:
1. Founder runs `/sdlc:docs distill`.
2. knowledge-engineer distills the accumulated learnings corpus into promotable ADR candidates via
   `refs/adr-pipeline.md`.
3. Candidates are presented at the founder-confirm gate; accepted candidates follow the ADR write path.

Edge cases:
- **No manifest** → silent no-op.
- **Corpus yields no promotable candidates** → reports nothing to distill; no PR.

### `/sdlc:init` opt-in scaffold flow

Happy path (new repo):
1. During init, after stack detection, the flow presents an **opt-in** prompt: scaffold
   `.claude/project/docs-manifest.md`?
2. **Accept** → manifest scaffolded with Diataxis rows and target paths pre-filled from the plugin
   taxonomy for the detected stack; docs features become active.
3. **Decline** → no manifest written; all docs features remain silent no-ops.

Edge case (re-run on existing repo):
- Init offers to **add** the manifest through its normal merge/confirm flow; an existing manifest is
  never silently overwritten (keep/merge/confirm).

### Post-QA auto-docs flow (`/sdlc:impl` and `/sdlc:auto`)

Happy path:
1. QA returns a clean verdict for the story.
2. principal-engineer playbook enters the post-QA docs phase and dispatches
   `knowledge-engineer docs sync <KEY>` **inline** on the story branch.
3. Docs commits land on the **same** story branch/PR (atomic review); **PR review replaces** the
   founder-confirm gate in this flow.
4. Sync uses the dual diff-source (story-branch-vs-develop AND merged-commit) appropriate to the phase.

Edge cases:
- **No manifest** → the docs phase no-ops; the impl/auto flow proceeds unchanged.
- **QA verdict not clean** → docs phase does not run.

## Out of Scope (v1)

- **Building or hosting a docs site.** Mintlify is already chosen for this repo, but the plugin stays
  stack-agnostic via manifest target paths — it writes docs, it does not build or deploy a site.
- **Auto-triggering on tag-push / CI events.** All modes are invoked explicitly (by the founder or by
  the impl/auto playbook). Tag-push / CI-event triggers are a later enhancement.
- **Marketing docs.** `gtm:docs` owns SEO / marketing documentation. `sdlc audit` covers technical
  accuracy only.
- **A deprecation period for `/sdlc:adr`.** Pre-1.0 plugin with a founder-only user base: `/sdlc:adr`
  is removed straight out, with a changelog entry, no deprecation window or shim.
- **Abstracting a shared pipeline ref.** `refs/docs-pipeline.md` copies the `adr-pipeline` shape; no
  shared-ref abstraction in this Epic.

## Dependencies

- **Upstream (shipped):** NA-43 — knowledge-engineer agent + `refs/adr-pipeline.md` + deterministic ADR
  index regeneration. This Epic extends that agent and reuses that pipeline; NA-43 must be merged
  (it is).
- **Story-level dependency graph (5-story rollout):**
  1. **Story 1 — Deterministic core:** `/sdlc:docs` command + `refs/docs-pipeline.md` + doc-type
     registry/manifest + `/sdlc:init` opt-in scaffold + `sync` mode (frontmatter-driven reference docs)
     + `llms.txt` regen. Foundation; lowest hallucination risk. No intra-Epic dependency.
  2. **Story 2 — Release mode:** changelog + release notes (ADR-linked) + migration-guide stub.
     Depends on Story 1.
  3. **Story 3 — Seed + audit modes:** founder-authored draft-for-review types (concepts, tutorials,
     integration guides) + staleness/drift scan. Depends on Story 1.
  4. **Story 4 — Playbook integration:** principal-engineer post-QA docs phase across `/sdlc:impl` and
     `/sdlc:auto`; dual diff-source sync. **Depends only on Story 1.**
  5. **Story 5 — Absorb `/sdlc:adr`:** remove the standalone command, rewire the founder-confirm gate to
     the docs command layer, wire `seed adr` + `distill` to `refs/adr-pipeline.md`, update NA-43-era
     docs. **Depends on Story 3** (seed mode).

## Product Checks

- **Roles affected:** founder / solo dev (invokes modes, reviews gated drafts); downstream
  plugin-consumer repos that ship a public product (activate doc types via manifest; no-manifest repos
  get silent no-op with zero setup cost).
- **Mobile / offline:** N/A — this is a CLI plugin feature.
- **Surfaces:** CLI plugin only (`sdlc` plugin commands, refs, and the knowledge-engineer agent).

## Open Questions

Carried from the Epic (owner: founder unless resolved here):

1. **Which Diataxis registry rows ship as plugin defaults vs. repo opt-in only?** — Open. Suggested
   default: ship the deterministic reference rows (command/agent/skill/config reference, hooks contract,
   error reference) + ADR + `llms.txt` as defaults; make narrative rows (tutorials, how-to, integration
   guides, concepts) opt-in. Founder to confirm.
2. **Is PR review a sufficient sign-off substitute for the founder-confirm gate in the playbook flow,
   for all generation modes including draft-for-review types?** — **Resolved by the Epic for Story 4:**
   yes, in the post-QA playbook flow, PR review replaces the founder-confirm gate (docs land on the same
   branch/PR for atomic review). Remains the founder-confirm gate for standalone `/sdlc:docs` invocations.
3. **`llms.txt` scope and format** — index-only (`llms.txt`) vs. full-content (`llms-full.txt`), and
   which sections are included. — Open; founder to confirm at spec time.
4. **Confirm this repo's docs-manifest target paths and Diataxis mapping onto the Mintlify `docs/` MDX
   tree.** — Open; repo-specific, founder to confirm.
5. **How deep is the release-mode migration-guide stub — headings/scaffold only, or attempt content?**
   — Open. Suggested default: headings/scaffold only in v1 (safer against hallucination); founder to
   confirm.
6. **Does `distill` mode need a non-ADR use later** (distilling the corpus into troubleshooting / FAQ
   entries)? — Open; out of scope for v1, flagged for a later Epic.
