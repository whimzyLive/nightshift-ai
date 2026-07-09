# Produce Landing Page Copy and Build Handoff — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [docs/superpowers/specs/NA-6.md](../specs/NA-6.md)
**Story:** NA-6 — Produce landing page copy and build handoff (Epic NA-2)
**Date:** 2026-07-09
**Agents required:** `ai-enablement-engineer` (only)

**Goal:** Author the gtm plugin's copy-production surface — the `content-writer` agent (landing-page ladder), the `voice-rules.md` anti-slop ref, and the thin `/gtm:site` orchestrator — so `/gtm:site` produces reviewed landing-page copy with a full SEO layer, always writes `docs/gtm/site-brief.md`, and dispatches sdlc's web-engineer when sdlc is present.

**Architecture:** Three new Markdown prompt artifacts under `plugins/gtm/`. `/gtm:site` (command) is the thin orchestrator — dispatch, gate, brand, route; it holds no copy logic. `content-writer` (agent) runs the skill ladder and stops at reviewed-ready copy + SEO layer. `voice-rules.md` (ref) is the anti-slop half of the shared copy-review gate consumed by both.

**Tech Stack:** Markdown agent/command/ref definitions for Claude Code plugins. No build system, no runtime, no tests-as-code — verification is markdown structural checks + consistency against the spec ACs.

## Execution order

This is a **docs / prompt-engineering** story. The entire implementable surface is Markdown under `plugins/gtm/`, owned by `ai-enablement-engineer` per the project-context workspace table (`plugins/ → ai-enablement-engineer`).

**No database, backend, offline-sync, web, or mobile phases apply** — there is no DB schema, HTTP API, app runtime, or sync layer in scope. All work is a single `ai-enablement-engineer` phase (marked **DEPENDENCY-FREE** in the tech-lead ladder — it consumes no artifacts from and produces none for other domain agents). Tasks run sequentially, one at a time, on the shared `feat/NA-6` branch.

Task order within the phase respects dependencies: **Task 1 (voice-rules ref)** ships first because both the agent's context contract and the command's gate reference it; **Task 2 (content-writer agent)** references the ref and defines the handoff artifact shape the command routes; **Task 3 (/gtm:site command)** dispatches the agent and runs the gate on its output.

## Global Constraints

Copied verbatim from the spec — every task's requirements implicitly include these:

- **Plugin-root resolution differs by artifact type.** Commands receive `${CLAUDE_PLUGIN_ROOT}` natively from the harness and use it directly (see `plugins/gtm/commands/init.md`). Agents do **not** — they read `.claude/.gtm-plugin-root` (a single line: absolute plugin root) and substitute its contents wherever `${CLAUDE_PLUGIN_ROOT}` appears (see `plugins/gtm/agents/product-marketing-manager.md`).
- **All three files are new**, all under `plugins/gtm/`, owner `ai-enablement-engineer`.
- **Shared copy-review gate boundary:** `copy-editing` is the gate's skill, run by `/gtm:site` (command step 3) — it is deliberately **not** on the `content-writer` agent's `skills:` list. This preserves the shared-gate boundary that NA-8's pulse reuses.
- **sdlc-presence detection** = the `.claude/.sdlc-plugin-root` marker file exists (decided — no `claude plugin list` parsing).
- **Gate FAIL = STOP.** Violations reported with offending spans; no automatic revision loop; nothing branded or handed off.
- **`docs/gtm/site-brief.md` is always written** (AC-6) as the durable handoff artifact, in both sdlc-present and sdlc-absent branches. Never silently overwritten — re-run guard (refine / regenerate / skip); `--overwrite` bypasses the prompt. Every written brief carries a one-line provenance header (date + source command).
- **`task=channel-draft` is deferred to NA-8** — the agent must document it as not-yet-implemented and STOP; no partial stub. (`NA-6 Blocks NA-8`.)
- All listed skills exist in the pinned `marketing-skills@marketingskills` v2.6.0 cache: `site-architecture`, `copywriting`, `cro`, `ai-seo`, `schema`, `offers`, `marketing-council`, `copy-editing`, `product-marketing`.

---

## Phase — AI-config (DEPENDENCY-FREE) `ai-enablement-engineer`

### Task 1: `plugins/gtm/refs/voice-rules.md` (new ref)

**Files:**
- Create: `plugins/gtm/refs/voice-rules.md`

**Interfaces:**
- Produces: the anti-slop quality bar consumed by Task 2 (context contract, read step 2) and Task 3 (copy-review gate, command step 3). Referenced as `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md`.

Prose guidance for the gate — **not** executable config, **no schema**. Adapted from the ECC marketing-agent hard-bans list (`https://github.com/affaan-m/ECC/blob/main/agents/marketing-agent.md`).

- [ ] **Step 1: Write the four required content sections**

  1. **Hard bans** — a concrete, enumerated list (not vibes). MUST include at minimum: AI-tell filler (`"in today's fast-paced world"`, `"unlock"`, `"unleash"`, `"elevate"`, `"supercharge"`, `"seamless"`, `"game-changer"`, `"revolutionary"`, `"cutting-edge"`), em-dash-as-crutch overuse, hedging (`"arguably"`, `"perhaps"`), empty superlatives without proof, and title-case marketing-speak headers.
  2. **Positioning discipline** — copy must trace to `.agents/product-marketing.md`; no invented claims, metrics, or customer quotes.
  3. **Voice layering rule** — these are the plugin **defaults**; a project's `.claude/project/marketing-context.md` **Voice** section may extend or override them. State merge precedence explicitly: project overrides win on direct conflict; plugin bans the project does not override remain in force; the copy gate enforces the **merged** result.
  4. **Gate outcome contract** — define PASS vs FAIL deterministically so `/gtm:site` and the `copy-editing` skill apply it identically: a FAIL lists each violation with its offending span; a FAIL blocks handoff.

- [ ] **Step 2: Verify (structural + consistency)**

  Run: `test -f plugins/gtm/refs/voice-rules.md && echo OK`
  Expected: `OK`

  Manual consistency checks (all must hold):
  - All four sections present (Hard bans / Positioning discipline / Voice layering rule / Gate outcome contract).
  - Every banned construct from the spec's minimum list is enumerated verbatim.
  - Merge precedence explicitly states "project overrides win on direct conflict".
  - Gate outcome contract states a FAIL lists each violation with its offending span and blocks handoff (matches spec AC-4 and Error Handling row "Copy-review gate FAIL").
  - No YAML/JSON schema block (prose only).

- [ ] **Step 3: Commit** — deferred to the single plan-level commit (parent owns the branch; no per-task commit required).

### Task 2: `plugins/gtm/agents/content-writer.md` (new agent)

**Files:**
- Create: `plugins/gtm/agents/content-writer.md`

**Interfaces:**
- Consumes: `plugins/gtm/refs/voice-rules.md` (Task 1) via the context contract.
- Produces: the handoff artifact (copy deck + full SEO layer) that Task 3's `/gtm:site` gates, brands, and routes. The agent's boundary ends at "reviewed-ready copy + SEO layer" — it does **not** apply brand tokens, run the gate, or route the build.

- [ ] **Step 1: Write frontmatter (mirror `product-marketing-manager.md` shape)**

  ```yaml
  ---
  name: content-writer
  description: >-
    Use to produce customer-facing marketing copy. NA-6 ladder: task=landing-page —
    page map/IA, copy deck, conversion pass, and full SEO layer (meta/OG, JSON-LD, llms.txt
    recommendation) for a product landing page. Hard-requires locked product-marketing context;
    refuses to draft without it. Dispatched by /gtm:site — never invoked inline by a command.
  model: opus
  tools: Read, Write, Bash, Skill
  skills:
    - site-architecture
    - copywriting
    - cro
    - ai-seo
    - schema
    - offers
    - marketing-council
  ---
  ```

  `offers` and `marketing-council` are declared but conditionally loaded (see ladder). `copy-editing` is deliberately **NOT** on this list — it belongs to the command's gate.

- [ ] **Step 2: Add the plugin-root resolver header verbatim from `product-marketing-manager.md`**

  Include the `.claude/.gtm-plugin-root` substitution block (lines 14–17 of `product-marketing-manager.md`), unchanged.

- [ ] **Step 3: Write the context contract (MUST, enforced before any drafting)**

  1. Read `.agents/product-marketing.md` (repo root — positioning / ICP / audience).
  2. Read `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md` (resolved via `.claude/.gtm-plugin-root`) — the anti-slop quality bar (Task 1).
  3. Read `.claude/project/marketing-context.md` for product basics and any project **Voice** overrides layered over plugin defaults.
  4. **STOP condition** — if `.agents/product-marketing.md` is absent or empty, STOP immediately with the exact error: *"Cannot produce copy — `.agents/product-marketing.md` is missing. Run `/gtm:init` to establish product-marketing context first."* Do not fall back to inferring positioning from the README or any other file.

- [ ] **Step 4: Write task dispatch**

  Agent accepts a `task` parameter from the dispatching command.
  - `task=landing-page` → the ladder in Step 5.
  - `task=channel-draft` → **deferred to NA-8**: document as not-yet-implemented and STOP with exactly: *"task=channel-draft is not available until NA-8."* Do not stub partial channel-draft behaviour.

- [ ] **Step 5: Write the `task=landing-page` skill ladder (run in this exact order)**

  | Step | Skill | Produces | Required? |
  |------|-------|----------|-----------|
  | 1 | `site-architecture` | Page map / IA: section order, URL, nav stubs, future-page slots | Required |
  | 2 | `copywriting` | Copy deck written to the IA from step 1 | Required |
  | 3 | `cro` | Conversion pass over the copy deck (CTA placement, friction, hierarchy) | Required |
  | 4 | `ai-seo` + `schema` | Meta/OG tags, JSON-LD blocks, llms.txt recommendation | Required |
  | — | `offers` | Sharpen CTA/offer framing | **Conditional** — only when CTA framing is weak |
  | — | `marketing-council` | Multi-perspective critique pass | **Conditional** — runs iff dispatch carries `--council` (flag is the sole trigger; "launch-critical" guides callers, not a second agent-side gate); skip + flag in return if the skill is unavailable; off by default; never in pulse |

- [ ] **Step 6: Document the deliberately-excluded skills (as intentional, not omissions)**

  `customer-research` (no real customer voice pre-launch — revisit at NA-11), `competitor-profiling` / `competitors` (differentiation lives in `.agents/product-marketing.md`, not per-run), `marketing-psychology` (subsumed by `copywriting`).

- [ ] **Step 7: Write the handoff-artifact output section**

  The agent produces the copy deck plus the full SEO layer as a single structured Markdown artifact and returns it **inline** + a summary (a session-temp scratch path is acceptable for very large artifacts — never the brief path). The output section MUST state the persistence boundary: the agent never writes `docs/gtm/site-brief.md` itself — persisting the brief is `/gtm:site`'s step, after the copy-review gate and re-run guard. The six required sections (the artifact shape the command persists to `docs/gtm/site-brief.md`):

  | Section | Contents |
  |---------|----------|
  | Page map / IA | Ordered section list, page URL/slug, nav stubs, future-page slots |
  | Copy deck | Per-section headline + body + CTA copy (brand-token annotated later, at command step 4) |
  | JSON-LD | Schema.org structured-data block(s) — e.g. `SoftwareApplication`, `Organization` |
  | Meta / OG | `<title>`, meta description, Open Graph + Twitter card tags |
  | llms.txt recommendation | Recommended `llms.txt` content/placement for AI-crawler discoverability |
  | Brand tokens | `nightshift-design` tokens (populated later, at command step 4) |

  State explicitly: the agent does NOT apply brand tokens, run the copy-review gate, or route the build — those are the command's steps.

- [ ] **Step 8: Verify (structural + consistency)**

  Run: `test -f plugins/gtm/agents/content-writer.md && echo OK`
  Expected: `OK`

  Run (YAML frontmatter parses): `head -20 plugins/gtm/agents/content-writer.md`
  Expected: valid `---`-delimited frontmatter with `name: content-writer`, `tools: Read, Write, Bash, Skill`, and the seven-skill list.

  Manual consistency checks:
  - `skills:` list is exactly the seven from spec; `copy-editing` is NOT present (AC boundary).
  - Plugin-root resolver header matches `product-marketing-manager.md` verbatim (agent mechanism, not command).
  - Context contract reads all three files and encodes the exact STOP error string (AC-1).
  - Ladder order is `site-architecture` → `copywriting` → `cro` → `ai-seo` + `schema`, with `offers` conditional and `marketing-council` behind `--council` (AC-2).
  - `task=channel-draft` STOPs with the exact NA-8 deferral string.
  - All six handoff sections present and match Task 3's routing expectations (AC-5).

### Task 3: `plugins/gtm/commands/site.md` (new command)

**Files:**
- Create: `plugins/gtm/commands/site.md`

**Interfaces:**
- Consumes: dispatches `content-writer` (Task 2) with `task=landing-page`; runs the gate using `plugins/gtm/refs/voice-rules.md` (Task 1) + the `copy-editing` skill.
- Produces: `docs/gtm/site-brief.md` (always) and, when sdlc is present, an `sdlc:web-engineer` dispatch with that brief as build input.

Thin orchestrator — **no copy logic in the command** (AC-3). Commands receive `${CLAUDE_PLUGIN_ROOT}` natively; use it directly (per `commands/init.md`). No `.claude/.gtm-plugin-root` resolver block.

- [ ] **Step 1: Write frontmatter + flags**

  Mirror `commands/init.md` command-frontmatter shape (a `description:` field). Document two optional flags:
  - `--council` — forwarded to the content-writer dispatch to enable the `marketing-council` critique pass; off by default; launch-critical pages only.
  - `--overwrite` — non-interactive override of the re-run guard: regenerate `docs/gtm/site-brief.md` without prompting (step 1b).

- [ ] **Step 2: Write the step ladder (1, 1b, 2–6)**

  1. **Precondition check** — verify `.claude/project/marketing-context.md` and `.agents/product-marketing.md` exist and are non-empty. If either fails, STOP: *"Run `/gtm:init` first — marketing context is not set up."* (Guard asymmetry stated honestly: the agent independently enforces only the product-marketing STOP; this precondition is the sole gate for marketing-context.) Then **ensure `.claude/.gtm-plugin-root` exists** — write it from the command's native `${CLAUDE_PLUGIN_ROOT}` when absent (gitignored per-machine cache the dispatched agent hard-requires).
  1b. **Re-run guard — decided BEFORE the copy run.** If `docs/gtm/site-brief.md` exists and no `--overwrite`: prompt **refine** / **regenerate** / **skip** now (mirrors the `/gtm:init` re-init guard). **skip** = no copy run at all — jump to routing (5c/5d) with the existing brief unchanged; report that it was not re-gated this run. `--overwrite` ⇒ regenerate, no prompt; no existing brief ⇒ fresh.
  2. **Dispatch content-writer** with `task=landing-page` (and `--council` when the flag is set). No inline copy work. The agent returns the handoff artifact inline (copy deck + SEO layer) plus its `marketing-council` status (ran / skipped-unavailable / not requested).
  3. **Copy-review gate — a verdict, not an edit** — the command applies the gate: the marketingskills `copy-editing` skill loaded **as review criteria only** (never as an editor; the gate must not rewrite the artifact), evaluated with `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md` (Task 1) as the merged project+plugin rules. Same gate as pulse. Emit exactly PASS or FAIL. On FAIL: report each violation with its offending span in the step-6 FAIL format and **STOP** — nothing branded or handed off; no automatic revision loop.
  4. **Apply brand tokens** — apply `nightshift-design` brand tokens sourced from `brand/BRAND_KIT.md` to the copy/section artifact so the handoff carries brand-correct typography, colour, and voice tokens (styling metadata on the copy deck, not a visual build).
  5. **Write the brief, then route the build:**
     - **5a. Persist per the step-1b guard decision** — fresh/regenerate/`--overwrite`: write this run's gated, branded artifact. **refine**: merge new changes into the existing brief, then **re-run the step-3 gate on the merged brief**; merged-FAIL ⇒ existing brief untouched, fresh artifact preserved at `docs/gtm/site-brief.new.md`, run ends with the FAIL report. Every written brief carries a one-line provenance header (date + source command).
     - **5b. Always write `docs/gtm/site-brief.md`** (AC-6) — the durable handoff artifact routed in **both** branches, regardless of sdlc presence. On a step-1b **skip**, the existing brief is retained; no copy run occurred.
     - **5c. sdlc installed** — additionally dispatch sdlc's web-engineer **by agent name** (`sdlc:web-engineer` via the Agent tool) with the brief as build input — never by a hardcoded file path. Detection: `.claude/.sdlc-plugin-root` marker file exists.
     - **5d. sdlc absent** — no dispatch; the brief alone is the deliverable.
     - Both branches carry the full SEO layer (AC-5): page map/IA, copy deck, JSON-LD, meta/OG, llms.txt recommendation all live in the brief.
  6. **Report** — completed-run fields (brief path, guard action, web-engineer dispatched or not) apply only when the run reached step 5; a step-3 gate-FAIL run instead states no brief was written and no guard ran, with the violation list (a refine-merge FAIL additionally names the preserved `site-brief.new.md`). Always include: gate result (PASS / FAIL / not-run-on-skip), the agent's `marketing-council` status, and any open copy decisions for the founder.

- [ ] **Step 3: Write the error-handling table**

  | Scenario | Behaviour |
  |----------|-----------|
  | `.agents/product-marketing.md` missing/empty | Command fails fast at step 1 with the "run `/gtm:init`" guidance; agent also STOPs. |
  | `marketing-context.md` missing/empty | Command STOPs at step 1 (precondition — the only guard for this file; the agent does not re-check it). |
  | `.claude/.gtm-plugin-root` missing | Non-error — step 1 writes it from the command's native `${CLAUDE_PLUGIN_ROOT}` before dispatch. |
  | Copy-review gate FAIL | Command STOPs after step 3; reports each violation + offending span in the step-6 FAIL format; nothing branded or handed off. |
  | Refine-merge gate FAIL | Existing brief untouched; fresh artifact preserved at `docs/gtm/site-brief.new.md`; run ends with the FAIL report — no routing. |
  | `task=channel-draft` requested | Agent STOPs: "task=channel-draft is not available until NA-8." |
  | sdlc absent at handoff | Non-error — the always-written brief is the deliverable; report notes no web-engineer dispatch. |
  | `docs/gtm/site-brief.md` already exists | Re-run guard (step 1b, BEFORE the copy run): prompt refine / regenerate / skip; `--overwrite` bypasses. Never silently overwritten. |
  | `brand/BRAND_KIT.md` missing | Degrade: proceed with unbranded copy deck, note missing brand kit in the report (do not hard-fail — brand is additive). |
  | `--council` passed but `marketing-council` unavailable | Agent skips the pass and flags the skip in its return (agent-side fallback); command surfaces it in the report. Non-fatal; gate still runs. |

- [ ] **Step 4: Verify (structural + consistency)**

  Run: `test -f plugins/gtm/commands/site.md && echo OK`
  Expected: `OK`

  Run (no accidental agent resolver *block* — commands use native `${CLAUDE_PLUGIN_ROOT}`; the marker path legitimately appears in step 1's bootstrap and the error table): `grep -cF 'substitute its contents wherever' plugins/gtm/commands/site.md`
  Expected: `0` (the resolver-block sentence exists only in agent files; a bare marker-path count no longer works — step 1 writes the marker by design)

  Manual consistency checks:
  - Command contains NO copy logic — only dispatch/gate/brand/route (AC-3).
  - Step 1 bootstraps `.claude/.gtm-plugin-root` from native `${CLAUDE_PLUGIN_ROOT}` when absent.
  - Step 1b decides the re-run guard BEFORE dispatch: refine/regenerate/skip; `--overwrite` bypasses; skip = no copy run, route existing brief.
  - Step 2 dispatches `content-writer` with `task=landing-page`; `--council` forwarded when set; return includes council status.
  - Step 3 gate is verdict-only — `copy-editing` as review criteria (never edits) + `refs/voice-rules.md`; FAIL → STOP, no revision loop; refine path re-gates the merged brief at 5a.
  - Step 5b always writes `docs/gtm/site-brief.md`; the six sections match Task 2's handoff shape (AC-5, AC-6).
  - sdlc detection = `.claude/.sdlc-plugin-root` marker; dispatch is by agent name `sdlc:web-engineer`, never a file path.
  - Provenance header on every written brief; refine-FAIL preserves the fresh artifact at `site-brief.new.md`.
  - Error-handling table has all ten rows matching the spec.

---

## Self-review (against spec)

**Spec coverage — every AC and section maps to a task:**
- AC-1 (context contract + STOP) → Task 2 Steps 3, 8.
- AC-2 (landing-page ladder order + conditionals) → Task 2 Step 5.
- AC-3 (`/gtm:site` no copy logic, dispatches with `task=landing-page`) → Task 3 Steps 1–2, 4.
- AC-4 (brand tokens + voice rules + shared copy gate) → Task 1 (ref) + Task 3 Steps 2 (gate), (brand).
- AC-5 (full SEO layer in handoff) → Task 2 Step 7 + Task 3 Step 2 (both branches).
- AC-6 (`docs/gtm/site-brief.md` always written; web-engineer dispatch when sdlc present) → Task 3 Step 2 (5b/5c/5d).
- Handoff artifact shape (6 sections) → Task 2 Step 7 (produced) + Task 3 Step 2 (persisted).
- Resolved decisions (marker-only sdlc detection, gate-fail STOP, re-run guard + `--overwrite`, brief always written, provenance header) → Global Constraints + Task 3 Steps 2–3.
- Error handling table (8 rows) → Task 3 Step 3.
- Plugin-root convention (agents vs commands) → Global Constraints + Task 2 Step 2 / Task 3 Step 1.

**Placeholder scan:** No TBD/TODO; all STOP strings, skill names, flags, and section names are literal from the spec.

**Consistency:** The six handoff sections named in Task 2 Step 7 are the same six the command persists (Task 3 Step 2) and verifies (Task 3 Step 4). Skill names match the pinned catalogue. `copy-editing` is consistently on the command's gate, never on the agent.

---

## Complexity

**Low** — single agent (`ai-enablement-engineer`), one dependency-free phase, three new Markdown files. No DB/backend/web/mobile/sync phases.
