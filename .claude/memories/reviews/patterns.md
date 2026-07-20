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

**Issues found:** Important x2 — (1) self-contradictory immutability rule in new writing-adrs SKILL.md ("rule holds even for typo fixes" + cosmetic exception in same sentence); (2) plugin.json version not bumped when new plugin-bundled skill shipped (both fixed in-review before merge, review round 1).
**Root causes:** (1) hedged prose trying to hold an absolute rule and its exception in one sentence; (2) version-bump convention lives in repo habit, not in a checklist the authoring agent reads.
**Preventions:** rules an autonomous agent will mechanically apply must resolve deterministically — state rule, then explicit narrow exception, never blended; any change under plugins/<plugin>/ ships with a plugin.json version bump in the same PR.
**Domains affected:** ai-enablement-engineer

## 2026-07-16 — Story NA-43

**Issues found:** Important x1 — pipeline defined draft status (proposed) but never the proposed→accepted transition, leaving the accepted-only write-path guard permanently unarmed; Minor x2 — literal bad-slug string in a warning (denylist trip hazard), unspecified combined-flag input (--distill "<focus>"). All fixed in-review before merge.
**Root causes:** lifecycle designed from the draft side only — nobody asked "what event flips the status?"; warning text quoted the exact anti-pattern token it warned against; mode tables written for the disjoint cases only.
**Preventions:** for any status/lifecycle field, spec the TRANSITION events, not just the states; never quote a forbidden token literally in guidance text; mode/argument tables must cover combined inputs or explicitly reject them.
**Domains affected:** ai-enablement-engineer

## 2026-07-16 — Story NA-43 (PR review round 2)

**Issues found:** 9 accepted (fixed in 5bf753d) — unspecified phase-2 dispatch payload (fresh subagent would re-draft founder-confirmed content), stale single-exception wording after adding a second exception, sanctioned-path enumeration missing a documented source, NNNN + date-branch race conditions under concurrent runs, over-broad guard suppressing the QA audit log, promoted-pattern tags escaping QA's read path, stale "not yet shipped" self-references, incomplete usage string. 1 rejected: claude-mem hard dependency (founder design decision).
**Root causes:** two-phase dispatch designed without an explicit data handoff contract; docs updated for the new rule but not the old rule's absolutist wording; uniqueness schemes (numbers, date branches) designed single-writer; guard scope stated ambiguously ("both appends").
**Preventions:** every cross-dispatch boundary needs an explicit payload contract (what, verbatim, via which channel); when adding exception N, grep for "only" claims about exceptions 1..N-1; any generated identifier needs a collision rule; guards state their exact scope per append site.
**Domains affected:** ai-enablement-engineer

## 2026-07-17 — Story NA-58

**Issues found:** 1 Critical — writing-docs SKILL.md frontmatter description exceeded the 1024-char validator limit (1162 chars); runtime truncation would have dropped the parameterization clause, undermining AC-1 signal and skill triggering. 1 Minor — garbled ADR-index parenthetical in the explanation template.
**Root causes:** description authored for completeness without running the plugin's own vendored validator (`skill-creator/scripts/quick_validate.py`); a sentence duplicated the body's "When to Use" section.
**Preventions:** run `quick_validate.py` on any new/edited plugin skill before committing; keep frontmatter descriptions ~800 chars like sibling skills; never duplicate body sections into the description.
**Domains affected:** ai-enablement-engineer

## 2026-07-17 — Story NA-51

**Issues found:** Important: prettier pre-commit mangled init.md Step 0 nested list (4-level nesting non-idempotent); Important: Step 0→4g merge-path gate relied on inference (AC5 reachability); Minor: story-context leakage in permanent plugin ref, formatting noise, inconsistent backticking.
**Root causes:** committing whichever form the prettier hook emits instead of restructuring to prettier-stable ≤3-level nesting; wiring a new init step into Step 0's jump list without re-checking the merge-run path that bypasses the prompt step.
**Preventions:** run prettier twice + diff before committing any init.md edit; when adding an init step, verify every Step 0 path (merge run, full re-run) can reach it; write plugin refs in timeless language (no story refs).
**Domains affected:** ai-enablement-engineer

## 2026-07-17 — Story NA-52

**Issues found:** Important: knowledge-engineer.md shared sections (branch/commit/return, completion checklist) not branched per dispatch type — ADR-only instructions were a live wrong-branch-cut hazard for docs-sync phase 2; Minor: diff range used local base (stale-base risk), manifest resolution checkout-dependency undocumented, fossil examples in registry schema.
**Root causes:** adding a second dispatch type to an agent without sweeping EVERY shared section for type-specific assumptions; spec text inherited verbatim without checkout-independence audit.
**Preventions:** when an agent gains a dispatch type, grep every section heading for unbranched instructions; prefer origin/<base> remote-tracking refs in all diff ranges.
**Domains affected:** ai-enablement-engineer

## 2026-07-19 — Story NA-48

**Issues found:** 1 Important — the new `code-comments-policy.md` (forbids informative comments incl. "subtle invariant" and "workaround and its reason") directly contradicted the standing "Conventions" line in the plugin agent definitions (`plugins/sdlc/agents/{platform,web}-engineer.md`) which endorsed commenting exactly those cases; two active agents received contradictory in-context instructions → perpetual review-gate churn. Fixed round 2 by deferring all 5 code-writing agent definitions' Conventions line to the policy doc (also closed the AC4 residual duplication). Minors (not blocking): publish-lag dangling `${CLAUDE_PLUGIN_ROOT}` pointer until 0.44.0 reinstall; prettier blank-line reflow noise.
**Root causes:** a new global policy doc was added without sweeping the agents' OWN definitions for pre-existing guidance that states the opposite — single-source (AC4) was enforced at the override layer but the plugin agent-definition layer still carried the copy-pasted contradiction.
**Preventions:** when introducing a policy/rule doc, grep every agent definition AND override for standing guidance on the same topic and reconcile (defer to the doc), not just the files named in the story scope; a single-source claim must hold across BOTH the override layer and the plugin agent-definition layer.
**Domains affected:** ai-enablement-engineer

## 2026-07-19 — Story NA-47

**Issues found:** No Critical/Important. Minor: `auto.md` completing-phase auto-merge hook example mixed placeholder conventions (`"$DONE_STATUS"` shell-var vs `<STORY_KEY>` bare vs `<DONE_STATUS>` prose) — risked the LLM emitting the literal `$DONE_STATUS` into the transition call, producing a spurious best-effort failure warning + Jira comment on every Full-Auto completion. Noted (not fixed): read-then-transition edge could post a failure comment on an already-done story if the status read fails; workflow must allow a direct current→done edge.
**Root causes:** command files are LLM-consumed instructions — a `$var` in an example is ambiguous between "substitute the resolved value" and "emit verbatim"; the impl carried the shell-var form over from the script into the prose example.
**Preventions:** in command/agent markdown, use ONE placeholder convention (`<ANGLE_BRACKET>`) for every value the model must substitute; never use `$shellvar` syntax in an example command string the model is meant to fill in. For best-effort Jira transitions, remember `--status` requires a direct workflow edge; distinguish "read failed" from "transition rejected" before posting a failure comment.
**Domains affected:** ai-enablement-engineer

## 2026-07-19 — Story NA-47 — loop review-fix

**Issues found:** Two robustness gaps a high-effort review caught that the first-pass review missed. (1) `auto-merge-pr.sh` silently no-op'd the transition when a story-key was supplied but `DONE_STATUS` resolved empty (misconfig) — re-introducing the exact stuck-In-Progress bug the story fixes, with no signal. (2) A flaky status read on an already-Done story defeated the idempotency guard and posted a contradictory "move it manually" comment. Rejected (out of scope): a migration/backfill of the new `## Pipeline` token for pre-NA-47 consumer repos — story Out-of-Scope excludes broader project-context schema changes.
**Root causes:** an AND-guard (`[ -n key ] && [ -n status ]`) collapses two distinct cases — "both empty = deliberate 1-arg back-compat" vs "key present, status empty = misconfig" — so the misconfig fell into the silent path. Idempotency was checked only on the pre-transition read, with no re-check after a failed attempt.
**Preventions:** when a guard's false branch has materially different meanings for different sub-cases, split it (add an `elif`) and make at least the dangerous sub-case loud. For best-effort external-state mutations, re-read the target state after a failed write before declaring failure — a flaky read or concurrent actor may already have reached the goal state.
**Domains affected:** ai-enablement-engineer

## 2026-07-20 — Story NA-46

**Issues found:** hard-pinned sdlc plugin-version literal embedded in skill prose
(`writing-adrs/SKILL.md` line 173: "regeneration tooling, shipped as of sdlc `0.33.0`") — rots on
every version bump since authored prose is never touched by the release process.
**Root causes:** a conditional ("pipeline adopted") framing borrowed the plugin's then-current
version number as a stand-in for "this capability exists in the plugin", instead of describing
the capability version-free.
**Preventions:** never embed a literal plugin self-version number (a `\d+\.\d+\.\d+` pattern near
"sdlc"/"gtm"/"plugin"/"shipped") in skill/ref/command/agent prose — describe capability existence
version-free (e.g. "shipped with this plugin", "where X is adopted") instead; reserve literal
version numbers for `plugin.json` fields and CHANGELOG entries, the only surfaces meant to track
releases.
**Domains affected:** ai-enablement-engineer
