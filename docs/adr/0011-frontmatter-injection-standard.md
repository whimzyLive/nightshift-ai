---
status: accepted
agents: []
source-stories: [NA-73]
trigger: [agent memory, frontmatter schema, dispatch-time context loading, adr authoring, memory tier ownership]
---

# 0011. Frontmatter-injection standard for agent-behaviour artifacts

## Status

Accepted

## Decision

We will make every agent-behaviour artifact — rule entries under `.claude/memories/agents/**`
and ADRs under `docs/adr/**` — self-describing via a small, fixed YAML frontmatter block, and
collect the artifacts applicable to a given dispatch by scanning that frontmatter mechanically
(`${CLAUDE_PLUGIN_ROOT}/scripts/collect-memory.sh`), never by routing an agent through a
hand-maintained or dispatch-read index file. Frontmatter carries exactly the fields collection
needs to filter and prioritize: `agent`/`agents`, `status`, and `trigger`. Full artifact bodies
are opened only for the entries a second, semantic pass selects — collection itself never reads
past the closing `---`.

## Context

Before this standard, per-agent memory lived as whole-file diaries
(`.claude/memories/agents/<name>.md`) appended to narratively at the end of every dispatch, and
ADRs were discovered by an agent reading `docs/adr/index.md` and following links its own judgment
picked out. Both paths share the same failure shape: a single growing file (or a single
hand-maintained index) that every relevant dispatch must read in full, that gives no mechanical
way to filter by relevance, that accumulates narrative story-specific prose alongside genuinely
reusable rules, and that turns two agents writing to the same file in the same story window into
a merge conflict. As the number of agents and stories grows, the read cost per dispatch grows
with it, and nothing in the format lets a dispatch skip content that doesn't apply to it.

Frontmatter injection is not a novel technique here — it mirrors how this plugin's own
`agents:`/`source-stories:` ADR frontmatter already let the ADR pipeline regenerate
`docs/adr/index.md` deterministically (see the existing `writing-adrs` skill and
`refs/adr-pipeline.md` §10) — but until this decision, that self-describing pattern applied only
to ADRs, and only to build a dev-facing index, not to drive dispatch-time collection.

## Alternatives Considered

### Single YAML/JSON memory database file

- Pros: one file to read, no directory scan, trivially queryable with standard tooling (`jq`,
  `yq`) without a bespoke awk parser.
- Cons: every agent writing a rule in a story window touches the same file, recreating exactly
  the merge-conflict problem the flat diaries already had; per-file granularity is what actually
  eliminates memory PR conflicts — two agents writing rules in the same story touch disjoint
  files, so there is nothing to merge. A single database file gives that back up for a marginal
  query-tooling convenience.

### Keep the index-file model, extend it to rules as well as ADRs

- Pros: no new collection script; agents already know how to read an index and follow links;
  smallest behavioural change from the status quo.
- Cons: an index file is itself a shared file every writer touches, so it inherits the same
  merge-conflict problem the flat diaries had; it also re-introduces a manual maintenance step
  (keeping the index in sync with the artifacts it lists) that frontmatter-driven collection
  removes entirely by deriving relevance mechanically instead of by a maintained pointer table.

### Frontmatter-injection standard (chosen)

- Pros: per-file granularity keeps concurrent writers on disjoint files; a mechanical first pass
  (`agent`/`agents` + `status`) narrows the candidate set cheaply before any body is read; the
  `trigger` field gives the collecting agent's semantic second pass a cheap hint without making
  relevance a machine-evaluated predicate; the same shape already worked for ADRs, so this
  extends a proven pattern rather than inventing a second one.
- Cons: requires every future rule entry and ADR to carry correctly-formed frontmatter, enforced
  only by a lint (`check-frontmatter.sh`) that — in this story — validates rule frontmatter but
  not ADR frontmatter (deferred to NA-74, since `trigger` is unbackfilled on the 10 pre-existing
  ADRs); a malformed or missing frontmatter block on a rule file is silently skipped by
  collection rather than surfaced at dispatch time, relying on the lint (CI-gated) to catch it
  instead.

## Consequences

- Collection is a two-pass read: a mechanical, frontmatter-only pass narrows every artifact under
  an agent's rule directories and every `accepted` ADR down to a short index-line list; a
  semantic, model-driven second pass over `trigger` phrases decides which full bodies are worth
  opening. Dispatch-time reads scale with what a dispatch actually needs, not with the size of
  the whole corpus.
- The three-tier ownership split is now explicit and enforced by directory/file convention rather
  than convention alone: **T0** (claude-mem episodic/local memory) is untouched by this standard
  and stays outside it entirely; **T1** (per-rule entries under `.claude/memories/agents/**`) is
  owned and lint-enforced by `ai-enablement-engineer`; **T2** (ADRs under `docs/adr/**`) is owned
  by `knowledge-engineer`. A candidate that already has an accepted T2 ADR is not also written as
  a T1 rule (T2 wins) — see the admission test in `refs/domain-agent-handoff.md`.
- `docs/adr/index.md` keeps its existing, unchanged role: a deterministically regenerated,
  dev-facing summary for a human skimming `docs/adr/`. It is explicitly **not** part of the
  dispatch read path — an agent never reads it to decide what applies to its work; collection
  reads ADR frontmatter directly. Nothing about its regeneration algorithm changes because of
  this decision.
- We are deliberately not introducing a memory-format version marker or a migration-chain
  mechanism in this decision. Two formats already coexist in a repo mid-migration (the legacy
  flat-diary fallback `collect-memory.sh` implements, and the new per-rule layout), and that
  two-way fallback is judged sufficient for the one supported transition. A third format, or a
  format that needs to evolve more than once, would justify a version marker and a real migration
  chain — that is a v3 need, not something to build speculatively now.
- Negative: rule frontmatter is validated by a CI-gated lint, but ADR frontmatter is not
  validated in this story (`trigger` is unbackfilled on ADRs 0001–0010, and turning on ADR
  frontmatter validation before that backfill would red-wall CI on day one). A malformed ADR
  frontmatter block is invisible to the lint until NA-74 backfills `trigger` and that validation
  is turned on.
- Revisit this decision if: a third memory-artifact shape (beyond rule entries and ADRs) needs
  frontmatter-driven collection and doesn't fit the existing `agent`/`agents` + `status` +
  `trigger` shape, or if the legacy-fallback two-format coexistence needs to support more than
  one prior format at once — either is the concrete trigger for the version-marker/migration-chain
  mechanism deferred above.
