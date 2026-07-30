# PRD — SDLC token and cost optimisation programme

| Field       | Value                                                                          |
| ----------- | ------------------------------------------------------------------------------ |
| Jira Epic   | [NA-76](https://whimzylive.atlassian.net/browse/NA-76)                         |
| Status      | In Progress                                                                    |
| Date        | 2026-07-30                                                                     |
| Surfaces    | Developer tooling — `plugins/sdlc` (published plugin) + `skills/`; no end-user UI |
| Children    | NA-77 (Done) · NA-78 (Done) · NA-79 (Done) · NA-80 (Done) · NA-81 (To Do)      |
| Related     | NA-79 (Relates) · NA-80 (Relates)                                              |
| Supersedes  | `sdlc-token-analysis.md`                                                       |
| Baseline    | repo `whimzyLive/nightshift-ai`, plugin `plugins/sdlc @ 0.45.2`, analysis dated 2026-07-28 |

## Problem Statement

Running one 8-point story end to end through `/sdlc:auto` (refine → PR) costs **$114**. At 25 stories a month that is **$34,236/yr**, and the tail is worse — NA-29 cost $461.77 and NA-65 cost $377.55 for a single story. The operator pays this on every story regardless of how much product value the story carries, so the cost of shipping is decoupled from the size of the change.

Two measured findings reframe where the money goes (source: 79 sessions with real `/sdlc:*` invocations, 54,914–69,369 requests; runtime figures come from the API's own `usage` records and are exact; static-file token counts are `bytes / 3.7` estimates, ±8%):

1. **Instructions are 51.8% of spend, not the ~30% previously assumed.** The plugin's own instruction files are paid for twice — once injected as commands/agents (35% floor) and again re-Read as files during a run (1,030 Read calls, 2.78M tokens, 16.8%).
2. **Only 6% of spend is actual source code.** Roughly 65% of everything Read is self-inflicted: files the plugin ships, or documents the SDLC itself just wrote (646,194 tokens of self-generated artifacts read back — a plan doc is loaded ~9× per story).

Amplification is the mechanism: a tool result emitted at turn 200 of an 1,100-turn session is re-billed ~900 times. Top-level sessions grow from 56k to 223k (median) to 309k (p75) resident and carry 42.9% of cost.

Prompt caching is already at **94.2% hit rate** — near ceiling, saving $31,478 versus uncached. It is a constraint to protect, not an opportunity to chase. There is no "turn on caching" move left.

Two secondary leaks are visible and unexplained: the RTK hook that CLAUDE.md claims rewrites `git status` → `rtk git status` is firing on **3.1%** of eligible calls (89 rtk vs 2,758 raw, 2.26M tokens straight past it), and the context-mode hook is firing on **0.34%** of calls.

## Solution

An eight-workstream programme that cuts the measured cost of one 8-point story from **$114.12 to $59.22 (−48.1%)** by shrinking and re-encoding the SDLC plugin's own instruction and context surface — without changing a single step of what the workflow does or what it produces.

The savings are multiplicative (each workstream applies to what the previous one left behind):

| #   | Workstream                      | Cost cut  | Risk    | Effort        |
| --- | ------------------------------- | --------- | ------- | ------------- |
| 1   | A — plugin instruction surface  | 26.8%     | LOW-MED | ~5 PRs        |
| 2   | F — context editing             | 7.0%      | MED     | 1 PR          |
| 3   | C — eliminate duplicate reads   | 6.9%      | LOW     | 1 PR          |
| 4   | B — self-generated artifact templates | 5.2% | LOW     | 1 PR          |
| 5   | E — bounded reads               | 4.9%      | MED     | contract edit |
| 6   | G — push top-level work to subagents | 4.2% | MED     | 1 PR          |
| 7   | H — loop passes to Haiku        | 3.0%      | MED     | 1 PR          |
| 8   | D — fix the RTK hook            | 2.3%      | LOW     | hours         |
|     | **Combined**                    | **48.1%** |         |               |

Per-story outcome: NA-6 $100.24 → $52.01 · 8-pt mean $114.12 → $59.22 · p75 $119.33 → $61.92 · NA-50 $168.50 → $87.43 · NA-65 (tail) $377.55 → $195.91. Token view for one 8-pt story: billed 143.0M → 121.5M; instruction load 466,887 → 225,250 (−52%).

Annualised: $13,694 → $7,106 (10 stories/mo, saves $6,588) · $34,236 → $17,765 (25/mo, saves $16,471) · $68,472 → $35,530 (50/mo, saves $32,942).

**Delivery model:** each workstream becomes its own child story under NA-76, worked one at a time, iteratively. Every workstream is independently shippable. Every child story is measured against the validation gates before and after.

### Workstream scope (A–H)

**A — Plugin instruction surface (26.8%, LOW-MED, ~5 PRs).** Fixes both halves of the 51.8%: the injected floor and the 1,030 re-Reads.

| Sub-item | Detail | Saved |
| --- | --- | --- |
| A1 table unpad | `lint-staged` runs `prettier --write --ignore-unknown`, which pads markdown tables. Add `plugins/sdlc/**/*.md` to `.prettierignore` plus a one-time unpad pass. Verify `scripts/check-plugin-docs-format.sh` won't re-pad. Zero semantic change. | 40,225 static / 54,161 per story |
| A2 tables → lean pseudocode | Beyond padding: 31% of unpadded table bytes | 9,861/story |
| A3 procedural prose → lean pseudocode | 47% on procedural sections only. Not on declarative sections (Why, Role, Inputs, Modes) — `agents/scrum-master.md` and `refs/analyze-protocol.md` score 0% procedural and stay prose | 36,111/story |
| A4 `refs/docs-pipeline.md` section split | 47.5k read whole for a §25/§26 post-QA sync needing ~5k. Split on existing numbered boundaries: `-core` (§1–9), `-release` (§10–14), `-seed` (§15–19), `-audit` (§20–24), `-postqa` (§25–26) | 19,894/story |
| A5 `commands/loop.md` fast path | Split into a fast path (~4k: arg parse, status probe, decision table, WAIT/exit) + `refs/loop-modes.md` (~10k, loaded only on fix branches) + `scripts/loop-budget.sh` (the budget block becomes an executed script, ~0 context) | 61,157/story |
| A6 `commands/auto.md` split | Epic orchestration (E0–E5b, 3,936 tok) moves to `refs/epic-orchestration.md`, loaded only when Step 0 returns `ITYPE=epic`. Two duplicated AI-Workflow JQL ladders move to `scripts/resolve-ai-workflow-mode.sh` | 6,004/story |
| A7 scrum-master lazy refs | Mode-3 assess returns 2 lines but loads the agent + jira-adf + story/bug templates + the acli skill. Load templates only when `QUALITY=triaged` | 9,695/story |
| A8 drop `subagent-driven-development` preload | 7,588 tok loaded at PE Step 0; the playbook dispatches directly with its own prompt contract | 7,588/story |
| A9 workspace-integrity guard → script | Snapshot/assert bash duplicated between PE Step 5 and QA Step 3 moves to `scripts/assert-workspace-clean.sh` | 1,200/story |
| A10 rationale extraction | Move design justification (Why inline, Why the split, transient-failure notes) to `docs/adr/` or non-loaded `refs/design-notes/`. Do last — some rationale is load-bearing | 2,500/story |

Pseudocode conversion rules are **mandatory** for A2/A3 and any later encoding work:

- Preserve exactly: fenced code, inline code, URLs, file paths, commands, exact contract strings.
- Rationale survives as `#` comments positioned next to the rule it justifies.
- Ship a one-time notation legend (~150 tok): `:=`, `->`, `⊆`, `ASSERT/ELSE`, first-match-wins.
- Never use a ` ```bash ` fence — use plain or ` ```text ` so nobody executes it.
- Gate: diff the branch inventory — count distinct outcomes before and after; the counts must match. Pseudocode's failure mode is silent omission of the else branch.
- Do not pseudocode judgment steps (PE Step 2 task derivation, Step 4 prompt-contract items 4/6, agent role definitions).

**B — Self-generated artifact templates (5.2%, LOW, 1 PR).** Apply the A1–A3 technique to the output formats our own agents produce: `skills/writing-specs`, the tech-lead plan template, `skills/writing-adrs`, the QA review-round file schema, the rule-entry schema. Spec docs alone carry 29,920 tok of prettier padding. Targets: avg 7,757 tok (spec doc) and 8,625 tok (plan doc).

**C — Eliminate duplicate reads (6.9%, LOW, 1 PR).** 19% of Read volume is the same path re-read within one transcript. Causes: a fresh domain agent per QA fix round re-reading the same files; read-after-edit verification; the PE Step 4 → QA Step 3 handoff losing content. Fixes: an explicit "content already in context — do not re-read" clause in the domain-agent prompt contract; carry read content forward in the handoff; confirm `SDLC agent reuse: enabled` is actually reusing (harness bug #76337 re-pays frontmatter on resume).

**D — Fix the RTK hook (2.3%, LOW, hours).** Measured adoption 3.1%. Diagnosis, not redesign — the hook is not firing.

**E — Bounded reads (4.9%, MED, prompt-contract edit).** Top 10% of reads carry 51% of Read tokens; p95 12,201, max 24,966. Mandate Grep-first then Read with `offset`/`limit` in the domain-agent prompt contract. Risk: partial reads miss context — pilot first.

**F — Context editing on top-level sessions (7.0%, MED, 1 PR).** Read amplifies 89×. Clearing stale tool results collapses the amplification factor. Risk: clearing context the agent still needs.

**G — Push top-level work into subagents (4.2%, MED, 1 PR).** Top-level 208,527 avg resident vs subagent 100,846 (2.1×). Candidates: QA gate runs, Step-7 AC verification reads, docs sync.

**H — Loop passes to Haiku (3.0%, MED, 1 PR).** 24,645 Opus requests. A loop pass is a status probe plus a 7-row decision table. Route the pass body to a cheap subagent and return the decision. Do this after A5. Keep fix branches (`/review-fix`) on the session model.

## User Story

**As** the solo founder/operator who runs every feature through the `/sdlc:*` pipeline,
**I want** the SDLC plugin to stop paying twice for its own instructions and re-reading its own output,
**So that** an 8-point story costs about half what it costs today and the pipeline stays economically viable at 25–50 stories a month — with no loss of spec, plan, review or PR quality.

Secondary personas:

- **As** the ai-enablement-engineer who owns `plugins/` and `skills/`, **I want** each optimisation shipped as an independently revertable PR with before/after measurements, **so that** a regression can be traced to one change and rolled back without unpicking the programme.
- **As** a downstream repo maintainer consuming the published `sdlc` plugin, **I want** command and agent contracts to be unchanged by this work, **so that** upgrading the plugin lowers my cost without me changing anything.

## Acceptance Criteria

Binary, testable at programme level. Each child story additionally carries its own workstream-scoped ACs.

1. Measured cost of one 8-point story via `/sdlc:auto` (refine → PR) drops to **≤ $60** (from a $114.12 mean baseline), evidenced by the API `usage` records for that story's transcripts.
2. Per-story **instruction load** drops to **≤ 230,000 tokens** (from 466,887), evidenced by a static+runtime inventory of instruction files loaded during one story.
3. All seven validation gates hold on the measured story: cache-read ratio **≥ 94%**; requests per story not increased; avg and peak resident **decreased**; QA rounds per story not increased; `Status: blocked` rate not increased; review findings per round not increased; loop passes per PR not increased.
4. Every one of workstreams **A (A1–A10), B, C, D, E, F, G, H** exists as a child story under NA-76, each with story points set and each with Phase 0/1/2/3 ordering expressed as Jira `Blocks` links.
5. Each merged child PR records a before/after measurement for its own workstream in the PR body — a workstream with no measurement is not accepted as complete.
6. No `/sdlc:*` command gains, loses, or reorders a step, and no artifact type (PRD, spec, plan, ADR, review file, PR) loses a section or contract string — verified by a content-contract diff on the artifacts produced by one full run.
7. For every file converted to pseudocode under A2/A3, the count of distinct decision outcomes (branches, including else/failure branches) is identical before and after — evidenced by a branch-inventory diff attached to the PR.
8. `prettier` no longer pads markdown tables under `plugins/sdlc/**/*.md`, and re-running the repo's format/lint pipeline (including `scripts/check-plugin-docs-format.sh`) does not re-pad them.
9. Phase 0 diagnosis is answered in writing before Phase 1 lands: why the context-mode hook fires on 0.34% of calls, why the RTK hook fires on 3.1%, and whether `Bash: cd` at 6.6% of exposure is an attribution artifact of `cd $WORKTREE && <compound>` rather than a real leak.
10. E, F and G are each piloted on one real story and validated against the gates **before** their cut-rates are counted in any savings claim; a pilot that fails a gate blocks that workstream from being reported as delivered.

## User Flows

### Happy path — programme execution

1. Operator resolves Phase 0 diagnosis (hours, no code change): context-mode hook adoption, RTK hook adoption, `Bash: cd` attribution. Findings are recorded on NA-76.
2. Operator sizes each workstream (story points) and runs `/sdlc:stories` on NA-76 to create the A–H child stories; Phase ordering is applied as `Blocks` links so the Principal Engineer playbook's Step-1 dependency gate enforces the sequence.
3. **Phase 1 (free / LOW risk):** A1 prettier unpad ships first (4.1%, zero semantic risk, ~1h). Then C (duplicate reads), B (artifact templates), D (RTK hook) in any order.
4. **Phase 2 (instruction surface):** A5 loop split → A4 docs-pipeline split → A6, A7, A8, A9. A2/A3 pseudocode conversion is folded into those same PRs rather than shipped standalone. A10 rationale extraction lands last.
5. **Phase 3 (MED risk, validate per story):** F context editing, G subagent offload, E bounded reads, H Haiku routing — each piloted on one real story.
6. For each child story: measure the gates on a real story **before** the change, ship the change, measure the same gates **after**, record both in the PR body, then merge.
7. When all A–H children are Done, the operator re-measures one 8-point story end to end and confirms AC-1 through AC-3 against the programme baseline.

### Edge case — a change cuts tokens but degrades the pipeline

1. A child story's after-measurement shows tokens down but QA rounds up (or `blocked` rate up, or review findings per round up).
2. The change is treated as a **net loss**, not a win: "if a change cuts tokens but raises QA rounds or blocked rate, it cost more than it saved."
3. The child story does not close on the token number alone — it is reverted or narrowed until the gates hold, and the programme's claimed savings are reduced by that workstream's share.

### Edge case — pseudocode silently drops a branch

1. An A2/A3 conversion reads correctly to a human but the else/failure branch of a decision is gone.
2. The mandatory branch-inventory diff catches the missing outcome before merge (counts must match).
3. If it escapes to a run instead, the symptom is an unhandled failure path in a live story — the fix is to restore the branch and add the missing outcome to that file's inventory baseline.

### Edge case — cache hit rate falls below the guardrail

1. A change reorders or fragments instruction loading such that the cache-read ratio drops below 94%.
2. The gate fails. Because caching already saves $31,478/yr, a cache regression can erase several workstreams' savings at once.
3. The change is reverted or re-sequenced so the stable prefix is preserved; caching is protected as a constraint, never traded for a smaller instruction surface.

### Edge case — a split file is now loaded in the wrong slice

1. A4/A5/A6 split a large ref into slices; a command loads a slice that does not contain the section it needs.
2. Symptom: the agent proceeds with missing procedure rather than failing loudly.
3. Every split must keep the existing numbered/section boundaries and each consuming command must name the slice it needs, so a missing section is a resolvable load error rather than silent omission.

### Edge case — Haiku routing returns a wrong loop decision

1. H routes a loop pass to a cheap model; the returned decision (wait / fix / stop) disagrees with what the session model would have decided.
2. Guardrail: loop passes per PR must not increase, and fix branches (`/review-fix`) stay on the session model — only the probe-and-decide pass body is routed.
3. If the decision quality degrades, H is reverted independently; it depends on A5 and touches nothing else.

## Out of Scope

- **Anything that is not the SDLC plugin's own instruction and context surface.** This is cost optimisation of that surface, nothing else.
- **Feature changes to the SDLC workflow.** No step is added, removed or reordered for product reasons.
- **Changes to what the workflow produces.** Specs, plans, PRDs, ADRs and PRs keep their content and contracts; only their encoding/format may change.
- **Prompt-caching work.** Hit rate is 94.2% (near ceiling). Caching is a constraint to protect, not an opportunity to chase.
- **Vendored plugin content** — `find-skills` and `skill-creator` (23,942 tok) are excluded from edits.
- **Declarative instruction sections** (Why, Role, Inputs, Modes) and judgment steps (PE Step 2 task derivation, Step 4 prompt-contract items 4/6, agent role definitions) are excluded from pseudocode conversion. `agents/scrum-master.md` and `refs/analyze-protocol.md` stay prose.
- **The "real ceiling" question** — how many of the 2,932 Reads and 1,104 requests per story are actually necessary. Higher ceiling than this whole Epic, not yet scoped, and explicitly a follow-up.
- **Unsized candidates / a possible ninth workstream** — deferred to a follow-up Epic decision, not delivered here.
- **NA-81 (plan-doc read slicing)** overlaps this programme's basis and is parked behind the A–H work; it is not a deliverable of this Epic as scoped today.

## Open Questions

Recorded 2026-07-28 as parked; not blocking Phase 0/1.

1. **Phase 0 diagnostics are questions, not tasks.** Three unknowns may resize their own workstreams once answered — context-mode hook firing on 0.34%, RTK hook on 3.1%, and whether `Bash: cd` at 6.6% of exposure is an attribution artifact. Decision needed: do these become their own child stories, or stay as an unticketed diagnosis pass?
2. **Story points are not set** on NA-76 or any child, and the SDLC plugin never writes them. Per-workstream sizing must be entered by hand before `/sdlc:stories` can decompose the Epic and before `/sdlc:auto` can route any child (a story with no points short-circuits at Step 2).
3. **Child stories for A–H are not yet created.** Confirm the intended shape: 8 linked child stories (one per workstream) with Phase 0/1/2/3 ordering as `Blocks` links — versus splitting A's ten sub-items into their own stories.
4. **E / F / G cut-rates are judgement, not measurement.** 4.9% / 7.0% / 4.2% are sized from measured distributions but the reduction percentages are estimates. Confirm they must be piloted and gate-validated before counting in any budget or savings claim.
5. **Unsized candidates — ninth workstream or follow-up Epic?** Product decision on where they land.
6. **The real ceiling is unknown.** Nobody has measured how many of the per-story Reads and requests are actually necessary. Owner and timing for scoping that question are undecided.
7. **Does the 48.1% target become a standing budget?** i.e. after delivery, is there a per-story cost guardrail that CI or the loop budget enforces, or is this a one-off reduction?

## Dependencies

Must exist first:

- **NA-77 (Done)** — active Jira site verified against project-context before Jira calls. Cost telemetry was collected while `acli` was pointed at the wrong site, which is why per-point figures are labelled noisy; correct attribution depends on this fix.
- **NA-78 (Done)** — `refine-feature` no longer hardcodes `--project ET`. Required for any child story to be created under the right project key.
- **NA-79 (Done)** — post-QA docs sync no longer burns 7M tokens for 2 edits on a 3-point story. This is the same waste class as workstream A4/G and its fix is part of the measured baseline.
- **NA-80 (Done)** — benchmark harness (SDLC vs superpowers vs spec-kit vs direct Opus). Provides the repeatable measurement rig the validation gates rely on.
- **Baseline telemetry and analyser scripts** — `~/.claude/projects/**/*.jsonl` transcripts, plus `/tmp/cache_an.py`, `/tmp/plugin_rows.json`, `scratchpad/cost8.py`. Without a reproducible before-measurement no child story can pass its gates.
- **Story points on NA-76 children** — hard blocker for `/sdlc:auto` routing (Step 2 short-circuits on missing points).
- **Internal ordering:** A5 must land before H. A10 must land after A2–A9. Phase 1 (A1, B, C, D) before Phase 2 (A4–A9). Phase 2 before Phase 3 (E, F, G, H).

Validation gates (measured per story, before and after — the programme's definition of "did not break anything"):

| Metric                                     | Source                        | Guardrail          |
| ------------------------------------------ | ----------------------------- | ------------------ |
| `cache_read_input_tokens` / total input     | transcript usage              | must stay ≥ 94%    |
| Requests per story                         | transcript count              | must not increase  |
| Avg + peak resident                        | transcript usage              | must decrease      |
| QA rounds per story                        | QA verdict block              | must not increase  |
| `Status: blocked` rate                     | QA verdict / agent returns    | must not increase  |
| Review findings per round                  | code-reviewer output          | must not increase  |
| Loop passes per PR                         | `pass_count` in budget file   | must not increase  |

## Product Checks

| Check              | Answer                                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Roles affected     | Founder/operator running `/sdlc:*` (pays the bill); ai-enablement-engineer (owns `plugins/`, `skills/`); downstream plugin consumers (inherit the savings); every SDLC agent persona whose instruction files are re-encoded |
| Mobile required    | No                                                                                                                                                         |
| Offline required   | No — the pipeline is online by definition (Jira via `acli`, GitHub via `gh`, model API)                                                                     |
| Surfaces           | Neither web nor mobile — developer tooling only: `plugins/sdlc/**` (commands, agents, refs, scripts, skills), root `skills/`, `.prettierignore`, hook config. No change to `apps/marketing`, `packages/ui`, or any user-facing product surface |
| Consumer-visible   | Yes, indirectly — `plugins/` and `skills/` are published artifacts, so encoding changes reach downstream repos on upgrade. Command/agent contracts must stay byte-compatible in meaning |
| Reversibility      | Per-workstream. Every child story is independently shippable and independently revertable                                                                  |

## Further Notes

- Measurement methodology: source `~/.claude/projects/**/*.jsonl` (including subagent transcripts); scope 79 sessions with real `/sdlc:*` invocations, 54,914–69,369 requests depending on filter. Static-file token estimates are `bytes / 3.7` (English markdown, ±8%) — not a tokenizer count. All runtime figures come from the API's own `usage` records and are exact.
- Per-story cost distribution (n=36 completed, PR raised): min $15.49 · p25 $50.61 · median $74.21 · p75 $119.33 · mean $104.75 · max $461.77. By points (session-labelled, noisy — `acli` was on the wrong site during collection): 3pt ≈ $57 · 5pt ≈ $80 · 8pt ≈ $100–120.
- Largest static plugin files (81 files, 331,415 tok): `refs/docs-pipeline.md` 47,514 · `commands/docs.md` 31,051 · `commands/init.md` 16,462 · `commands/loop.md` 14,637 (×10 loop passes/story) · `refs/principal-engineer-playbook.md` 11,964 · `commands/auto.md` 11,859 · `agents/knowledge-engineer.md` 9,884 · `agents/scrum-master.md` 9,807 · `refs/qa-engineer-playbook.md` 9,256.
- Encoding experiments were hand-converted and measured (`scratchpad/orig.md`, `cave.md`, `notation4.md`, `pseudo.md`, `tbl_orig.md`, `tbl_pseudo.md`). Full-plugin projection with padding exact and pseudocode ratios sampled by category: 73,022 tok saved of 331,415 = 22% static; per-story instruction load 466,887 → 366,755. Some encodings were rejected; the rejection list and known limitations live verbatim in the NA-76 comments.
- Risk key used throughout: **LOW** = no behavioural change; **MED** = needs per-story validation.
