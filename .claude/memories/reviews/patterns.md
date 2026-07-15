## 2026-07-07 — Story NA-3

**Issues found:** 1 Critical (init.md Step 5 verified PMM doc AFTER finalize mv — atomic guarantee broken, false "discarded" claim), 3 Important (portability-lint hardcoded to plugins/sdlc so new plugin unscanned; repo .gitignore missing .claude/.gtm-plugin-root while hook writes it pre-init; finalize mv order made marketing-context.md land first, so half-finalize looked like existing foundation to the re-init guard), 4 Minor (plan verify-check assumed string-array deps; sed dot-mangling; grep-based package.json reads; undocumented drift-check omission).
**Root causes:** verify/finalize ordering not treated as part of the atomic contract; single-plugin assumptions baked into shared tooling; sentinel-file semantics (guard keys on marketing-context.md) not linked to write ordering.
**Preventions:** any atomic-write step must verify ALL preconditions before the first mv; the file a re-init/existence guard keys on must be written LAST; shared repo tooling (lint) must enumerate plugins/\*/, never hardcode one; when a hook writes a file outside init, the repo shipping the hook needs the gitignore entry itself.
**Domains affected:** platform-engineer

## 2026-07-09 — Story NA-4

**Issues found:** 2 Important — (1) writer-facing meta-instructions + literal ${CLAUDE_PLUGIN_ROOT} embedded inside the rendered template fence in marketing-context-template.md (would leak into every generated marketing-context.md); (2) init.md Step 6 closing summary still claimed NA-4 config "doesn't exist yet" after this run wrote it.
**Root causes:** fenced template block treated as documentation surface rather than verbatim render surface; unblocks list not updated when the story being implemented graduated from "future" to "done".
**Preventions:** anything inside a template fence must be pure renderable output — protocol/meta prose belongs in Fill rules or outside the fence; when a command edits its own summary text, re-read neighbouring paragraphs for stale claims about the story being implemented.
**Domains affected:** ai-enablement-engineer

## 2026-07-10 — Story NA-16

**Issues found:** 1 Critical — gsap.matchMedia registered with ONLY the '(prefers-reduced-motion: reduce)' condition, so the animation callback never fired for no-preference users (ACs 2/3/4 silently unmet; page rendered correct but static). 3 Important — tests mocked mm.add and invoked the handler with fabricated conditions (green-lit the broken registration); homepage went force-dynamic with an unguarded Payload findGlobal (DB outage = homepage 500, revalidate hook dead under force-dynamic); new `hero` table had no production migration path (dev-only schema push).
**Root causes:** matchMedia mental model inverted — assumed callback always runs with conditions as booleans, but GSAP fires it only when ≥1 named condition MATCHES; mocks encoded the same wrong contract as the implementation; availability of the CMS fetch path not considered when switching the route to per-request SSR.
**Preventions:** gsap.matchMedia must always register complementary conditions (reduce + no-preference) so one always matches; when mocking a third-party contract, derive mock behaviour from real matchMedia semantics (stub window.matchMedia) so the test would fail if the registration is wrong; any request-time CMS/DB read on a public route needs a try/catch fallback to defaults; jsdom cannot see "animation never runs" bugs — add a real-browser smoke for motion work.
**Domains affected:** web-engineer

## 2026-07-11 — Story NA-26

**Issues found:** 1 Important — principal-engineer.md profile's "Collecting results" section still extracted only Status/Note while the new contract added Summary/Skills loaded (the same "discards the line it must verify" defect class the spec fixed in the playbook); 1 Minor — markdown indentation attached the STOP-and-redispatch consequence to one sub-bullet instead of the parent rule.
**Root causes:** parallel prose (agent profile vs playbook) duplicating a contract drifts when the spec's change inventory names only some of the duplicate sites; prettier's markdown reflow silently reattaches lazy-continuation paragraphs, undoing plain dedents.
**Preventions:** when a contract changes, grep ALL files that restate it (agents/ + refs/) — not just the spec's inventory; verify markdown structure post-commit (prettier may reparse), use blank-line-separated paragraphs for bullet-scope-critical prose.
**Domains affected:** ai-enablement-engineer

## 2026-07-12 — Story NA-27

**Issues found:** 1 Critical — qa-engineer-playbook Steps 5/6 kept `git merge --ff-only origin/<BRANCH>` in the primary cwd, which post-NA-27 (primary stays on main) fast-forwards local main onto the story branch, corrupting the primary and stranding the learnings commit; 5 Important — worktree-setup registration grep prefix-collision (NA-2 vs NA-27), case-1 re-entry deadlock on never-pushed branch, GC destroying in-flight zero-commit worktrees, primary-guard assert-empty false-positive on pre-dirty checkout, impl.md markdown-fence corruption from an auto-formatter.
**Root causes:** changing WHERE git operations run (primary → worktree) invalidates every sibling step that assumed cwd==story-branch — the spec's change inventory listed only Step 3; substring greps over porcelain output collide on key prefixes; guards asserting absolute state (empty) instead of deltas (snapshot-compare) false-positive on pre-existing conditions; prettier reflow corrupts fenced blocks containing unbalanced quotes.
**Preventions:** when relocating an operation's working directory, audit EVERY git command in the same file for cwd assumptions; porcelain line matches must be exact-line (`grep -qxF`); guards compare against captured snapshots, never assert cleanliness; run a fence-balance check after any auto-formatted markdown commit.
**Domains affected:** ai-enablement-engineer

## 2026-07-12 — Story NA-25

**Issues found:** 1 Important — scrum-master.md step-10a/10b fenced bash blocks corrupted (fences 24→20) and sub-bullets flattened by the phase-4 body edit + prettier pre-commit pass; 1 Minor (accepted) — check-agent-skill-preloads.sh vacuously exit-0 on missing/empty agents dir.
**Root causes:** editing agent-body markdown near indented pseudo-list items (`10a.`/`10b.`) re-triggers the known prettier fence-corruption class (same as NA-27 e510d80); guard scripts that glob a directory without existence/zero-match checks silently pass when the target moves.
**Preventions:** after ANY auto-formatted markdown commit touching plugins/, run a fence-count sanity check against the pre-edit count and verify prettier idempotence (second --write must be a no-op); every CI guard script fails loudly on missing target dir and zero-glob (nullglob + count check) — never vacuous green.
**Domains affected:** ai-enablement-engineer

## 2026-07-14 — Story NA-7

**Issues found:** 4 Important — (1) ``tr -d '`- '`` in a finding-ID extraction pipeline deletes hyphens INSIDE kebab-case IDs, breaking the idempotency contract; (2) idempotency guard matched group-slug/branch only, ignoring the findingIds the input contract carries — cross-shape re-runs would duplicate PRs; (3) four stale step-N cross-references after implementation renumbered spec steps; (4) escaped globs (`docs/star-star/star.md`) inside a fenced template block written verbatim into generated config.
**Root causes:** `tr -d` is char-class deletion, not token stripping — wrong tool for framed-token extraction (use anchored sed); guards written against one matching key when the contract supplies two; renumbering steps without grepping cross-refs; prettier round-trip escaping inside fenced markdown templates.
**Preventions:** extract framed tokens with an anchored sed capture group, never `tr -d`; when an input contract carries a field for dedup, the guard MUST consume it — slug-level matching alone is a red flag; after renumbering steps in LLM-executed markdown, grep `[Ss]tep[- ][0-9]` across every touched file; check generated-template glob rows render literally (wrap in code spans, verify prettier idempotence).
**Domains affected:** ai-enablement-engineer

## 2026-07-15 — Story NA-44

**Issues found:** Important x2 — (1) self-contradictory immutability rule in new writing-adrs SKILL.md ("rule holds even for typo fixes" + cosmetic exception in same sentence); (2) plugin.json version not bumped when new plugin-bundled skill shipped.
**Root causes:** (1) hedged prose trying to hold an absolute rule and its exception in one sentence; (2) version-bump convention lives in repo habit, not in a checklist the authoring agent reads.
**Preventions:** rules an autonomous agent will mechanically apply must resolve deterministically — state rule, then explicit narrow exception, never blended; any change under plugins/<plugin>/ ships with a plugin.json version bump in the same PR.
**Domains affected:** ai-enablement-engineer
