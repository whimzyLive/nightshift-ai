# Produce Landing Page Copy and Build Handoff — Technical Spec

**Story:** NA-6 — Produce landing page copy and build handoff
**Epic:** NA-2 — GTM plugin (source of truth for nightshift-ai)
**Feature:** [docs/features/2026-07-07-gtm-marketing-plugin.md](../../features/2026-07-07-gtm-marketing-plugin.md)
**Design:** [docs/superpowers/specs/2026-07-07-gtm-plugin-design.md](2026-07-07-gtm-plugin-design.md) (content-writer + `/gtm:site` sections, amended via PR #52)
**Date:** 2026-07-09

> **Story type:** prompt-engineering / plugin authoring. This project's implementable surface is
> Markdown agent/command/ref definitions under `plugins/gtm/` (owner: `ai-enablement-engineer` per
> the project-context workspace table). There is **no database, HTTP API, web/mobile app runtime, or
> offline-sync layer in scope** — those template sections are omitted per the writing-specs rule.
> The spec below defines the three prompt artifacts to author and the exact contracts each must
> encode.

## Story acceptance criteria (traceability)

The Jira story's six ACs, numbered here so in-spec references (`AC-<n>`) are self-contained:

- **AC-1** — `content-writer` agent definition exists with the context contract: reads
  `.agents/product-marketing.md` + voice rules before drafting; stops with a clear error when the
  product-marketing context is missing.
- **AC-2** — the agent encodes the landing-page skill ladder: `site-architecture` → `copywriting` →
  `cro` → `ai-seo` + `schema` (`offers` conditional; `marketing-council` behind `--council`).
- **AC-3** — `/gtm:site` contains no copy logic; it dispatches `content-writer` with
  `task=landing-page`.
- **AC-4** — generated copy uses the project's brand tokens and voice rules and passes the shared
  copy-review gate (`copy-editing` + voice rules — same gate as pulse) before handoff.
- **AC-5** — the build handoff artifact carries the full SEO layer: page map/IA, copy deck, JSON-LD
  blocks, meta/OG tags, llms.txt recommendation.
- **AC-6** — `docs/gtm/site-brief.md` is always written as the durable handoff artifact; when sdlc
  is installed the build handoff additionally dispatches its `web-engineer` agent with that brief
  as build input.

## Overview

Ships the gtm plugin's single copy-production role — the `content-writer` agent — with its context
contract and the `task=landing-page` skill ladder, plus the thin `/gtm:site` orchestrator and the
`refs/voice-rules.md` anti-slop quality bar it depends on. Result: `/gtm:site` produces reviewed
landing-page copy carrying a full SEO layer, always writes `docs/gtm/site-brief.md` as the durable
handoff artifact, and additionally dispatches sdlc's web-engineer when sdlc is installed — without
the founder writing copy or wiring the build.

## Artifacts

Three files to author, all under `plugins/gtm/` (owner: `ai-enablement-engineer`). Plugin-root
path resolution follows the established gtm convention, which differs by artifact type: **commands**
receive `${CLAUDE_PLUGIN_ROOT}` natively from the harness and use it directly (see
`plugins/gtm/commands/init.md`); **agents** do not — they read `.claude/.gtm-plugin-root` (a single
line: the absolute plugin root) and substitute its contents wherever `${CLAUDE_PLUGIN_ROOT}`
appears, identical to the header block already in `plugins/gtm/agents/product-marketing-manager.md`.

| # | Path | Status | Owner |
|---|------|--------|-------|
| 1 | `plugins/gtm/agents/content-writer.md` | new | ai-enablement-engineer |
| 2 | `plugins/gtm/refs/voice-rules.md` | new | ai-enablement-engineer |
| 3 | `plugins/gtm/commands/site.md` | new | ai-enablement-engineer |

---

### Artifact 1 — `plugins/gtm/agents/content-writer.md` (new agent)

The single copy-production role for the plugin. NA-6 ships the definition with the context contract
and the **landing-page ladder only**; NA-8 extends the same file with the `task=channel-draft`
ladder (that edge is why `NA-6 Blocks NA-8`).

**Frontmatter** (mirror the shape of `product-marketing-manager.md`):

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

All listed skills exist in the pinned `marketing-skills@marketingskills` v2.6.0 cache (verified:
`site-architecture`, `copywriting`, `cro`, `ai-seo`, `schema`, `offers`, `marketing-council`).
`offers` and `marketing-council` are declared but conditionally loaded (see ladder). `copy-editing`
is deliberately **not** on the agent — it is the copy-review gate's skill, run by `/gtm:site`
(command step 3), preserving the shared-gate boundary NA-8's pulse reuses.

**Plugin-root resolver header** — include the same `.claude/.gtm-plugin-root` substitution block
verbatim from `product-marketing-manager.md`.

**Context contract (MUST, enforced in the body before any drafting):**

1. Read `.agents/product-marketing.md` (repo root — positioning / ICP / audience, owned by the
   marketingskills `product-marketing` skill).
2. Read `${CLAUDE_PLUGIN_ROOT}/refs/voice-rules.md` (resolved via `.claude/.gtm-plugin-root`) — the
   plugin's anti-slop quality bar (Artifact 2).
3. Read `.claude/project/marketing-context.md` for the product basics and any project **Voice**
   overrides layered over the plugin defaults.
4. **STOP condition:** if `.agents/product-marketing.md` is absent or empty, STOP immediately with a
   clear error — copy is never produced without locked positioning. Error text:
   *"Cannot produce copy — `.agents/product-marketing.md` is missing. Run `/gtm:init` to establish
   product-marketing context first."* Do not fall back to inferring positioning from the README or
   any other file.

**Task dispatch:** the agent accepts a `task` parameter passed by the dispatching command.

- `task=landing-page` — the ladder below (NA-6).
- `task=channel-draft` — **explicitly deferred to NA-8.** In NA-6 the agent MUST document this task
  as not-yet-implemented and STOP with: *"task=channel-draft is not available until NA-8."* Do not
  stub partial channel-draft behaviour.

**`task=landing-page` skill ladder (consultancy ordering — structure → copy → conversion →
discoverability; run in this exact order):**

| Step | Skill | Produces | Required? |
|------|-------|----------|-----------|
| 1 | `site-architecture` | Page map / IA: section order, URL, nav stubs, future-page slots | Required |
| 2 | `copywriting` | Copy deck written to the IA from step 1 | Required |
| 3 | `cro` | Conversion pass over the copy deck (CTA placement, friction, hierarchy) | Required |
| 4 | `ai-seo` + `schema` | Meta/OG tags, JSON-LD blocks, llms.txt recommendation | Required |
| — | `offers` | Sharpen CTA/offer framing | **Conditional** — loaded only when CTA framing is weak (available in the pinned catalogue) |
| — | `marketing-council` | Multi-perspective critique pass | **Conditional** — runs iff the dispatch carries `--council` (the flag is the sole trigger; "launch-critical" guides callers on when to pass it, not a second agent-side gate); if the skill is unavailable the agent skips the pass and flags the skip in its return; off by default; never in pulse |

**Deliberately excluded from the ladder** (documented in the agent as intentional, not an omission):
`customer-research` (no real customer voice pre-launch — revisit at NA-11), `competitor-profiling` /
`competitors` (differentiation lives in `.agents/product-marketing.md`, not per-run),
`marketing-psychology` (subsumed by `copywriting`).

**Output — the handoff artifact (see "Handoff artifact shape" below):** the agent produces the copy
deck plus the full SEO layer as a single structured artifact and returns it inline + a summary (a
session-temp scratch location is acceptable for very large artifacts — never the brief path; the
agent never writes `docs/gtm/site-brief.md` itself).
The agent does **not** apply brand tokens, run the copy-review gate, or route the build — those are
the command's orchestration steps (Artifact 3). The agent's boundary ends at "reviewed-ready copy +
SEO layer".

---

### Artifact 2 — `plugins/gtm/refs/voice-rules.md` (new ref)

The plugin's ECC-derived anti-AI-slop quality bar — the hard-bans half of the shared copy-review
gate. Referenced by both `content-writer` (context contract) and `/gtm:site` (gate), and, once NA-8
lands, by `/gtm:pulse` (the design's "same gate as pulse"). Adapted from the
[ECC marketing-agent](https://github.com/affaan-m/ECC/blob/main/agents/marketing-agent.md) hard-bans
list.

**Content requirements:**

- **Hard bans** — a concrete, enumerated list of banned constructs (not vibes). At minimum: AI-tell
  filler ("in today's fast-paced world", "unlock", "unleash", "elevate", "supercharge", "seamless",
  "game-changer", "revolutionary", "cutting-edge"), em-dash-as-crutch overuse, hedging
  ("arguably", "perhaps"), empty superlatives without proof, and title-case marketing-speak headers.
- **Positioning discipline** — copy must trace to `.agents/product-marketing.md`; no invented claims,
  metrics, or customer quotes.
- **Voice layering rule** — these are the plugin **defaults**; a project's `marketing-context.md`
  **Voice** section may extend or override them. State the merge precedence explicitly: project
  overrides win on direct conflict; plugin bans that the project does not override remain in force.
  The copy gate enforces the **merged** result.
- **Gate outcome contract** — define what a PASS vs FAIL looks like so `/gtm:site` and `copy-editing`
  can apply it deterministically: FAIL lists each violation with the offending span; a FAIL blocks
  handoff.

This ref is prose guidance for the gate, not executable config — no schema.

---

### Artifact 3 — `plugins/gtm/commands/site.md` (new command)

Thin orchestrator — **no copy logic in the command** (AC-3). It dispatches, gates, brands, and routes.

**Plugin-root resolution** — commands receive `${CLAUDE_PLUGIN_ROOT}` natively; use it directly,
per the `commands/init.md` convention. No `.claude/.gtm-plugin-root` resolver block (that is the
agents' mechanism).

**Flags:**

- `--council` (optional) — forwarded to the content-writer dispatch to enable the
  `marketing-council` critique pass; off by default; intended for launch-critical pages only.
- `--overwrite` (optional) — non-interactive override of the re-run guard: regenerate
  `docs/gtm/site-brief.md` without prompting (see step 1b).

**Step ladder:**

1. **Precondition check** — verify `.claude/project/marketing-context.md` and
   `.agents/product-marketing.md` exist and are non-empty. If either fails, STOP: *"Run `/gtm:init`
   first — marketing context is not set up."* (Guard asymmetry, stated honestly: the agent
   independently enforces only the `.agents/product-marketing.md` STOP; this precondition is the
   sole gate for `marketing-context.md`.) Then **ensure `.claude/.gtm-plugin-root` exists** —
   it is a gitignored per-machine cache the dispatched agent hard-requires; the command holds the
   native `${CLAUDE_PLUGIN_ROOT}` value and writes the marker when absent, before dispatch.
1b. **Re-run guard — decided BEFORE the copy run** (brief existence is knowable up front; the
   founder's choice must not cost a wasted dispatch). If `docs/gtm/site-brief.md` exists and no
   `--overwrite`: prompt **refine** / **regenerate** / **skip** now (mirrors the `/gtm:init`
   re-init guard). **skip** = no new copy run at all — jump to routing (5c/5d) with the existing
   brief unchanged, and report that it was not re-gated this run (founder's explicit choice).
   `--overwrite` ⇒ regenerate without prompting; no existing brief ⇒ fresh.
2. **Dispatch content-writer** with `task=landing-page` (and `--council` when the flag is set). No
   inline copy work — the command only passes the task through. The agent returns the handoff
   artifact (copy deck + SEO layer) inline, plus its `marketing-council` status (ran /
   skipped-unavailable / not requested).
3. **Copy-review gate — a verdict, not an edit.** The command applies the gate: the marketingskills
   `copy-editing` skill is loaded **as review criteria only** (never as an editor — the gate must
   not rewrite or "improve" the artifact), evaluated together with `refs/voice-rules.md`
   (Artifact 2) as the merged project+plugin rules. Same gate as pulse. Emit exactly PASS or FAIL.
   On FAIL: report each violation with its offending span and **STOP** — nothing is branded or
   handed off, no automatic revision loop (decided — see Resolved decisions).
4. **Apply brand tokens** — apply `nightshift-design` brand tokens sourced from `brand/BRAND_KIT.md`
   (the project brand kit) to the copy/section artifact so the handoff carries brand-correct
   typography, colour, and voice tokens. (Brand-token application is styling metadata on the copy
   deck, not a visual build.)
5. **Write the brief, then route the build:**
   - **5a. Persist per the step-1b guard decision** — fresh/regenerate/`--overwrite`: write this
     run's gated, branded artifact. **refine**: merge the new changes into the existing brief, then
     **re-run the step-3 gate on the merged brief** (retained old spans were never gated this run —
     only the merged whole passing satisfies AC-4 for the actual handoff artifact); merged-FAIL ⇒
     existing brief untouched, this run's fresh artifact preserved at `docs/gtm/site-brief.new.md`,
     run ends with the FAIL report. Each written brief carries a one-line provenance header
     (date + source command).
   - **5b. Always write `docs/gtm/site-brief.md`** (AC-6) — the brief is the durable handoff
     artifact routed in **both** branches, regardless of sdlc presence (on a step-1b **skip**, the
     existing brief is retained as that artifact; no copy run occurred).
   - **5c. sdlc installed** — additionally dispatch sdlc's web-engineer agent **by agent name**
     (`sdlc:web-engineer` via the Agent tool) with the brief as its build input — never by a
     hardcoded file path (in a consumer repo the sdlc plugin lives under the
     `.claude/.sdlc-plugin-root` marker's root, not at `plugins/sdlc/…`). Detection: the
     `.claude/.sdlc-plugin-root` marker file exists (decided).
   - **5d. sdlc absent** — no dispatch; the brief alone is the deliverable and the founder wires
     the build up or installs sdlc later.
   - **Both branches carry the full SEO layer** (AC-5) — the page map/IA, copy deck, JSON-LD
     blocks, meta/OG tags, and llms.txt recommendation live in the brief.
6. **Report** — completed-run fields (brief path, guard action, web-engineer dispatched or not)
   apply only when the run reached step 5; a gate-FAIL run instead states explicitly that no brief
   was written and no guard ran, with the violation list. Always include: gate result (PASS / FAIL
   / not-run-on-skip), the agent's `marketing-council` status, and any open copy decisions for the
   founder.

---

## Handoff artifact shape

The single structure the content-writer produces and `/gtm:site` routes. It is always persisted as
`docs/gtm/site-brief.md` and MUST carry the full SEO layer; when sdlc is present the same brief is
also passed to the web-engineer dispatch. Defined as a document
structure (the artifact is Markdown with embedded code blocks — this is a docs/prompt story, not a
typed API); the required sections:

| Section | Contents |
|---------|----------|
| Page map / IA | Ordered section list, page URL/slug, nav stubs, future-page slots |
| Copy deck | Per-section headline + body + CTA copy, brand-token annotated after step 4 |
| JSON-LD | Schema.org structured-data block(s) for the page (e.g. `SoftwareApplication`, `Organization`) |
| Meta / OG | `<title>`, meta description, Open Graph + Twitter card tags |
| llms.txt recommendation | Recommended `llms.txt` content/placement for AI-crawler discoverability |
| Brand tokens | `nightshift-design` tokens applied to the deck (populated at command step 4) |

The six sections are written as one Markdown brief at `docs/gtm/site-brief.md` (always). When
web-engineer is dispatched, the brief is passed as the agent's build spec input.

## Permissions Detail

No runtime auth/permission model — these are Claude Code plugin prompt artifacts, not a
multi-tenant service. The only access boundaries are structural:

| Actor | Can | Cannot |
|-------|-----|--------|
| `/gtm:site` (command) | Orchestrate: dispatch writer, run gate, apply brand, route handoff | Contain copy logic (AC-3) |
| `content-writer` (agent) | Produce copy deck + SEO layer via the ladder | Apply brand tokens, run the gate, route the build, or draft without product-marketing context |
| Founder | Run `/gtm:site`, review gate output, approve/edit copy, wire the build | — |

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| `.agents/product-marketing.md` missing/empty | Agent STOPs with the "run `/gtm:init`" error; no copy produced. Command also fails fast at step 1 with the same guidance. |
| `marketing-context.md` missing/empty | Command STOPs at step 1 (precondition — the only guard for this file; the agent does not re-check it). |
| `.claude/.gtm-plugin-root` missing | Non-error — step 1 writes it from the command's native `${CLAUDE_PLUGIN_ROOT}` before dispatch (gitignored per-machine cache, routinely absent on a fresh clone). |
| Copy-review gate FAIL | Command STOPs after step 3; reports each violation + offending span in the step-6 FAIL format; nothing branded or handed off. |
| Refine-merge gate FAIL | Existing brief untouched; this run's fresh gated artifact preserved at `docs/gtm/site-brief.new.md`; run ends with the FAIL report — no routing. |
| `task=channel-draft` requested (NA-6) | Agent STOPs: "task=channel-draft is not available until NA-8." |
| sdlc absent at handoff | Non-error — the brief (always written) is the deliverable; the report notes no web-engineer dispatch occurred. |
| `docs/gtm/site-brief.md` already exists on re-run | Re-run guard (step 1b, BEFORE the copy run): prompt refine / regenerate / skip; `--overwrite` bypasses the prompt. Never silently overwritten. |
| `brand/BRAND_KIT.md` missing | Degrade: proceed with unbranded copy deck and note the missing brand kit in the report (suggested default — do not hard-fail; brand is additive to copy). |
| `--council` passed but `marketing-council` skill unavailable | Agent skips the pass and flags the skip in its return (documented agent fallback); command surfaces it in the report. Non-fatal; gate still runs. |

## Out of Scope

- **`task=channel-draft` ladder** — per-channel drafts, media/image generation, postiz
  integration-schema compliance. Owned by **NA-8** (which extends this same agent file).
- **`/gtm:pulse`, `/gtm:launch`, `/gtm:report`, `/gtm:docs`** commands — other stories.
- **Actual page deployment / hosting** — the handoff ends at the brief (always) and the
  web-engineer dispatch (when sdlc is present); no deploy.
- **`customer-research`** in the ladder — no real customer voice pre-launch; revisit at NA-11.
- **`competitor-profiling` per run** — differentiation belongs in `.agents/product-marketing.md` at
  init / PMM-brief time.
- **The full launch asset set** (demo, launch posts, directory checklist) — NA-10.
- **KPI / channel config** — NA-4 / NA-5.

## Resolved decisions

All former open questions were decided by the product owner in PR #53 review (2026-07-09):

- **sdlc-presence detection** — the `.claude/.sdlc-plugin-root` marker file is sufficient; no
  `claude plugin list` parsing.
- **Gate FAIL behaviour** — STOP on errors. Violations are reported and the command stops; no
  automatic revision loop.
- **`site-brief.md` re-run behaviour** — never overwrite silently. Re-run guard (step 1b, decided before the copy run) prompts
  refine / regenerate / skip, mirroring the `/gtm:init` re-init guard; `--overwrite` is the explicit
  non-interactive bypass. Every written brief carries a provenance header (date + source command).
- **Brief always written** — `docs/gtm/site-brief.md` is produced in both handoff branches; the
  web-engineer dispatch (when sdlc is present) consumes it rather than replacing it (AC-6).
