# Bootstrap gtm plugin config via /gtm:init — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [docs/superpowers/specs/NA-3.md](../specs/NA-3.md)
**Epic context:** [docs/superpowers/specs/2026-07-07-gtm-plugin-design.md](../specs/2026-07-07-gtm-plugin-design.md)
**Story:** [NA-3](https://whimzylive.atlassian.net/browse/NA-3) — Bootstrap gtm plugin config via /gtm:init (Epic NA-2; blocks NA-4, NA-5, NA-6, NA-7, NA-8, NA-11)
**Date:** 2026-07-07
**Agents required:** platform-engineer (only)
**Estimated complexity:** Medium — single agent, one sequential phase, 8 task groups (breadth of files, not layer depth)

**Goal:** Stand up the `gtm` plugin package and its `/gtm:init` command — the marketing counterpart to sdlc's `/init` — that gates on Postiz reachability, detects product info, invokes the marketingskills `product-marketing` skill, and atomically writes a version-controlled marketing foundation.

**Architecture:** New standalone plugin under `plugins/gtm/` mirroring `plugins/sdlc/` layout. Two cross-marketplace dependencies (`postiz@postiz-agent`, `marketing-skills@marketingskills`), NO superpowers, NO sdlc dependency. The complete shared script set is vendored so gtm reaches back into nothing outside its own package. `/gtm:init` does all setup in-command (no agent dispatch); the `product-marketing-manager` agent ships as a definition only.

**Tech Stack:** Markdown (command/agent/ref files) + Shell (vendored session scripts + hooks). Package manager: pnpm. Verification: `tools/portability-lint.sh`, `jq`, `shellcheck` (when available).

## Global Constraints

Every task's requirements implicitly include this section. Exact values copied verbatim from the spec:

- **Plugin name:** `gtm` — **version:** `0.1.0` (independent of sdlc's version line).
- **Dependencies (exactly two):** `postiz@postiz-agent` and `marketing-skills@marketingskills`. **NO `superpowers`. NO `sdlc`.**
- **marketplace.json `allowCrossMarketplaceDependenciesOn` final value:** `["claude-plugins-official", "postiz-agent", "marketingskills"]` (pre-existing `claude-plugins-official` stays for sdlc's superpowers dep; append the other two).
- **Postiz env-var contract:** `POSTIZ_API_URL` (backend URL) + `POSTIZ_API_KEY` (API key). Both required at the init gate. **Only env-var NAMES are persisted to disk — never the values.**
- **Postiz reachability gate:** via the `postiz` CLI (`postiz auth:status`) — gtm never hand-rolls HTTP against Postiz.
- **`.agents/product-marketing.md`** is owned/maintained by the marketingskills `product-marketing` skill — init invokes the skill, does NOT author a template for it. No `refs/agent-binding-template.md`.
- **Path resolution:** every script/ref invocation resolves via `${CLAUDE_PLUGIN_ROOT}/scripts/…` — NEVER a `plugins/sdlc/` path.
- **`.claude/.gtm-plugin-root`** marker is **gitignored** (deliberate divergence from sdlc's committed `.sdlc-plugin-root`).
- **`platform-engineer`** owns `plugins/` + `tools/` and is the only active agent. `brand/` is read-only detection input — no changes under `brand/`.
- **Atomic write:** init stages its own writes to the session temp dir and moves them into place only after all succeed; on any mid-write failure, delete the staging area and leave config paths untouched.

---

## Execution order

Single sequential phase — `platform-engineer` only. This story is pure plugin machinery (markdown + vendored shell + manifest edits): no database, no offline-sync, no web/mobile UI, so the phase ladder collapses to Phase 1. Task groups within the phase are ordered by dependency; each ends with an independently verifiable deliverable. Work happens on the existing `feat/NA-3` branch.

## Phase 1 — Plugin machinery [platform-engineer]

### Task Group 1 — Package skeleton + vendored script set

**Files:**
- Create dir tree: `plugins/gtm/{.claude-plugin,commands,agents,hooks,scripts,refs}/`
- Vendor copy (functional equivalents of the sdlc originals):
  - `plugins/gtm/scripts/session-complete.sh` (from `plugins/sdlc/scripts/session-complete.sh`)
  - `plugins/gtm/scripts/cleanup-tmp.sh` (from `plugins/sdlc/scripts/cleanup-tmp.sh`)
  - `plugins/gtm/scripts/tmp-dir.sh` (from `plugins/sdlc/scripts/tmp-dir.sh`)
  - `plugins/gtm/scripts/session-key.sh` (from `plugins/sdlc/scripts/session-key.sh`) — shared sibling dependency of all three above; MUST be vendored or the other three break / silently re-introduce an sdlc-path dependency.

**Interfaces produced:** `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh`, `.../cleanup-tmp.sh`, `.../tmp-dir.sh`, `.../session-key.sh` — all self-contained within `plugins/gtm/`.

- [ ] **[platform-engineer]** Create the six subdirectories under `plugins/gtm/`.
- [ ] **[platform-engineer]** Copy the four scripts from `plugins/sdlc/scripts/` into `plugins/gtm/scripts/`, preserving executable bit (`chmod +x`).
- [ ] **[platform-engineer]** Grep each vendored script for any residual `plugins/sdlc/` or `sdlc` path/reference and any sibling call — confirm every internal call targets the vendored sibling (e.g. `session-key.sh` resolved relative to the script's own dir), NOT an sdlc path.
- [ ] **[platform-engineer]** Verify: `for f in plugins/gtm/scripts/*.sh; do bash -n "$f" && echo "OK $f"; done` (syntax check, all print OK) and `! grep -rn "plugins/sdlc" plugins/gtm/scripts/` (no residual sdlc paths — expect empty).

### Task Group 2 — Manifest + marketplace registration

**Files:**
- Create: `plugins/gtm/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**`plugin.json` required fields:**
- `name`: `"gtm"`
- `version`: `"0.1.0"`
- `description`: one-line marketing-engine description
- `author`: mirror the sdlc manifest's author shape
- `dependencies`: `["postiz@postiz-agent", "marketing-skills@marketingskills"]` — exactly these two. NO `superpowers`, NO `sdlc`.

**`marketplace.json` two edits (leave the `sdlc` entry untouched):**
1. `allowCrossMarketplaceDependenciesOn` → `["claude-plugins-official", "postiz-agent", "marketingskills"]`.
2. Append to `plugins`: `{ "name": "gtm", "source": "./plugins/gtm", "description": "..." }`.

- [ ] **[platform-engineer]** Read `plugins/sdlc/.claude-plugin/plugin.json` for the author/field shape, then write `plugins/gtm/.claude-plugin/plugin.json` with the fields above.
- [ ] **[platform-engineer]** Edit `.claude-plugin/marketplace.json`: extend the allowlist to the three-element array and append the `gtm` plugins entry.
- [ ] **[platform-engineer]** Verify: `jq -e '.dependencies == ["postiz@postiz-agent","marketing-skills@marketingskills"]' plugins/gtm/.claude-plugin/plugin.json` and `jq -e '.name=="gtm" and .version=="0.1.0"' plugins/gtm/.claude-plugin/plugin.json`.
- [ ] **[platform-engineer]** Verify: `jq -e '.allowCrossMarketplaceDependenciesOn == ["claude-plugins-official","postiz-agent","marketingskills"]' .claude-plugin/marketplace.json` and `jq -e '[.plugins[].name] | index("gtm") and index("sdlc")' .claude-plugin/marketplace.json` (both gtm and sdlc present).

### Task Group 3 — SessionStart/SessionEnd hooks

**Files:**
- Create: `plugins/gtm/hooks/hooks.json`
- Create: `plugins/gtm/hooks/load-marketing-context.sh`

**Reference:** `plugins/sdlc/hooks/hooks.json` and `plugins/sdlc/hooks/load-project-context.sh`.

**`hooks.json` registrations:**
- SessionStart → `load-marketing-context.sh` (resolved via `${CLAUDE_PLUGIN_ROOT}/hooks/…`).
- SessionEnd → the vendored `${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-tmp.sh`.

**`load-marketing-context.sh` behaviour (modeled on sdlc's `load-project-context.sh`):**
- (a) Write `.claude/.gtm-plugin-root` marker (single-line absolute plugin root) so later gtm commands/subagents resolve `${CLAUDE_PLUGIN_ROOT}`.
- (b) Inject `.claude/project/marketing-context.md` as `additionalContext` when present.
- Inert-safe: emit nothing and `exit 0` in a repo without gtm config.
- Distinct marker filename `.claude/.gtm-plugin-root` (never collides with sdlc's `.claude/.sdlc-plugin-root`).

- [ ] **[platform-engineer]** Read `plugins/sdlc/hooks/load-project-context.sh` and `plugins/sdlc/hooks/hooks.json` as structural reference.
- [ ] **[platform-engineer]** Write `plugins/gtm/hooks/load-marketing-context.sh` (marker write + context injection + inert-safe exit 0), `chmod +x`.
- [ ] **[platform-engineer]** Write `plugins/gtm/hooks/hooks.json` with SessionStart → loader and SessionEnd → vendored `cleanup-tmp.sh`.
- [ ] **[platform-engineer]** Verify: `jq -e '.' plugins/gtm/hooks/hooks.json` (valid JSON) and `bash -n plugins/gtm/hooks/load-marketing-context.sh`.

### Task Group 4 — Refs (detection, verification, templates)

**Files (all Create):**
- `plugins/gtm/refs/postiz-verify.md`
- `plugins/gtm/refs/product-detect.md`
- `plugins/gtm/refs/marketing-context-template.md`
- `plugins/gtm/refs/docs-gtm-readme-template.md`

Do **NOT** author `refs/agent-binding-template.md` — the marketingskills `product-marketing` skill owns `.agents/product-marketing.md`.

**`postiz-verify.md`** (Step 2 gate protocol, via the `postiz` CLI — never HTTP):
1. Env vars present — `POSTIZ_API_URL` AND `POSTIZ_API_KEY` both set and non-empty.
2. Auth probe — `postiz auth:status` reports authenticated.
- Distinct STOP messages: (a) missing/empty env var(s) — name the exact var; (b) not authenticated — credentials invalid/expired/absent; (c) CLI/connection error — backend at `POSTIZ_API_URL` unreachable. Every failure = STOP, write nothing. Values read from env at run time, never persisted.

**`product-detect.md`** (Step 3, read-only; writes nothing) — resolve each field by first matching source, unresolved → interview gap for Step 4:
| Field | Sources (in order) | Fallback |
| --- | --- | --- |
| name | `package.json` `name` → git remote repo name → top-level `README.md` H1 | prompt |
| one-liner | `package.json` `description` → README tagline/subtitle → `brand/BRAND_KIT.md` tagline (if present) | prompt |
| repo | `git remote get-url origin` (normalize to `owner/name` or URL) | prompt |
| landing URL | `package.json` `homepage` → first external link/badge in `README.md` | prompt (blank allowed) |
`brand/` is read-only here.

**`marketing-context-template.md`** — token template for `.claude/project/marketing-context.md` with the spec schema sections: Product (`name`, `one-liner`, `repo`, `landing URL`), Postiz (`API URL env var` default `POSTIZ_API_URL`, `API key env var` default `POSTIZ_API_KEY` — NAMES only, secret-hygiene rule), Voice (`voice overrides` — empty at init). Points at `.agents/product-marketing.md` as the canonical product-marketing detail.

**`docs-gtm-readme-template.md`** — template for `docs/gtm/README.md` with the three required sections: (1) Purpose, (2) Directory map (`digests/`, `briefs/`, downstream placeholders), (3) What init writes vs what downstream stories populate.

- [ ] **[platform-engineer]** Write `plugins/gtm/refs/postiz-verify.md` (two-condition gate + three distinct STOP messages).
- [ ] **[platform-engineer]** Write `plugins/gtm/refs/product-detect.md` (the four-field detection table + fallbacks).
- [ ] **[platform-engineer]** Write `plugins/gtm/refs/marketing-context-template.md` (schema tokens + secret-hygiene rule, names-only).
- [ ] **[platform-engineer]** Write `plugins/gtm/refs/docs-gtm-readme-template.md` (the three required sections).
- [ ] **[platform-engineer]** Verify: `test -f` on all four refs; confirm `! test -f plugins/gtm/refs/agent-binding-template.md` (must NOT exist); `grep -L "POSTIZ_API_KEY" plugins/gtm/refs/postiz-verify.md` returns empty (key env var referenced).

### Task Group 5 — `/gtm:init` command (Steps 0–6 + Final)

**Files:**
- Create: `plugins/gtm/commands/init.md`

**Reference:** `plugins/sdlc/commands/init.md` (re-init guard, prerequisite gate, read-only scan, one-question-at-a-time prompts, no-placeholder write rule, atomic staged writes, session-complete release).

**Frontmatter:** carries a `description:` line (mirror sdlc). Always interactive; `$ARGUMENTS` ignored. Runs top-to-bottom, STOP at the first failure with an actionable message; a failed prerequisite must never leave half-written config. All steps in-command — no agent dispatch.

**Step ladder (must be implemented exactly):**
- **Step 0 — Re-init guard:** detect existing `.claude/project/marketing-context.md`; if present, `AskUserQuestion` → Keep existing (print summary, STOP, write nothing) / Merge new findings (re-detect, backfill only absent template fields, preserve set values) / Re-run full setup (re-prompt with existing values as defaults, rewrite). Both Merge and Re-run **re-enter at Steps 1–2** before any write.
- **Step 1 — Dependency check:** verify both `postiz@postiz-agent` (+`postiz` skill) and `marketing-skills@marketingskills` (+`product-marketing` skill) installed. If missing, install idempotently: `claude plugin marketplace add gitroomhq/postiz-agent` → `claude plugin install postiz@postiz-agent --scope project`; and `claude plugin marketplace add coreyhaines31/marketingskills` → `claude plugin install marketing-skills@marketingskills --scope project`. STOP with actionable message if either cannot be installed. Writes no config.
- **Step 2 — Postiz prerequisite gate:** apply `${CLAUDE_PLUGIN_ROOT}/refs/postiz-verify.md`. STOP + write nothing on failure (AC-1).
- **Step 3 — Product info detection:** apply `${CLAUDE_PLUGIN_ROOT}/refs/product-detect.md` (read-only, AC-2).
- **Step 4 — Product-marketing context:** invoke the marketingskills `product-marketing` **skill** in-command, seeded with the Step-3 detection, to create/maintain `.agents/product-marketing.md` (auto-draft → founder-corrects, or from-scratch interview). No agent dispatch (AC-2, AC-3).
- **Step 5 — Write gtm config (atomic):** stage init's own writes to the session temp dir via `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh` → `./.tmp/<session>`, move into place only after ALL succeed. Writes `.claude/project/marketing-context.md` (from the template, no placeholder tokens remaining), the `docs/gtm/` scaffold (`README.md` from `docs-gtm-readme-template.md`, `digests/.gitkeep`, `briefs/.gitkeep`), the gitignored `.claude/.gtm-plugin-root` marker, and idempotently appends `.tmp/` + `.claude/.gtm-plugin-root` to `.gitignore` (mirror sdlc Step 4e). Then **verify `.agents/product-marketing.md` exists** (Step 4 output) — STOP if absent, discard staging (AC-3, AC-5).
- **Step 6 — Post-init checklist:** print what was written, remind to keep `POSTIZ_API_URL` + `POSTIZ_API_KEY` set, show how to commit the foundation (AC-5), and name the follow-up stories NA-4 / NA-5 / NA-6 / NA-7 / NA-8 / NA-11 under Epic NA-2.
- **Final — Release session:** run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` (vendored) as the last action — silent no-op outside the worker.

- [ ] **[platform-engineer]** Read `plugins/sdlc/commands/init.md` for structure (guard, gate, scan, prompts, atomic staging, release).
- [ ] **[platform-engineer]** Write `plugins/gtm/commands/init.md` implementing Steps 0–6 + Final above, with the Error-Handling table from the spec baked into the step behaviours (each failure → STOP + write nothing / discard staging). Reference refs and scripts only via `${CLAUDE_PLUGIN_ROOT}/…`.
- [ ] **[platform-engineer]** Verify: `test -f plugins/gtm/commands/init.md`; confirm frontmatter has a `description:` line; `! grep -n "plugins/sdlc" plugins/gtm/commands/init.md` (no sdlc paths — expect empty); confirm the string `session-complete.sh` appears (Final release step present).

### Task Group 6 — `product-marketing-manager` agent definition

**Files:**
- Create: `plugins/gtm/agents/product-marketing-manager.md`

**Reference:** sdlc's `product-manager` agent as the structural mirror.

**Content:** PMM takes a vague marketing request / product context → a **GTM brief** (positioning, messaging, target audience, channel rationale, launch angle), written to `docs/gtm/briefs/<date>-<slug>.md`. Uses the marketingskills skills (`product-marketing` for context; `launch` / `content-strategy` / `copywriting` as needed) and the `postiz` skill for any Postiz operation — **never raw HTTP**. **Ship the definition only** — brief-producing workflows are downstream (NA-4..NA-8, NA-11); do NOT wire it into `/gtm:init`.

- [ ] **[platform-engineer]** Read the sdlc `product-manager` agent definition for the frontmatter + structure convention.
- [ ] **[platform-engineer]** Write `plugins/gtm/agents/product-marketing-manager.md` (GTM brief output convention `docs/gtm/briefs/<date>-<slug>.md`, marketingskills + postiz skills, never raw HTTP, definition-only note).
- [ ] **[platform-engineer]** Verify: `test -f plugins/gtm/agents/product-marketing-manager.md`; confirm it references `docs/gtm/briefs/` and does NOT hand-roll HTTP against Postiz (`! grep -in "curl\|http" ...` against Postiz — no raw-HTTP-to-Postiz language).

### Task Group 7 — Plugin README

**Files:**
- Create: `plugins/gtm/README.md`

**Reference:** `plugins/sdlc/README.md` structure.

**Content:** document the plugin, the two dependencies (`postiz@postiz-agent`, `marketing-skills@marketingskills`), and the `POSTIZ_API_URL` / `POSTIZ_API_KEY` env-var contract (names-only persisted, values live in the environment).

- [ ] **[platform-engineer]** Read `plugins/sdlc/README.md` for the structure.
- [ ] **[platform-engineer]** Write `plugins/gtm/README.md` (deps + env-var contract documented).
- [ ] **[platform-engineer]** Verify: `test -f plugins/gtm/README.md`; `grep -q "POSTIZ_API_URL" plugins/gtm/README.md && grep -q "POSTIZ_API_KEY" plugins/gtm/README.md`.

### Task Group 8 — Portability + full-package verification

**Files:** none (verification only).

- [ ] **[platform-engineer]** Verify portability: `bash tools/portability-lint.sh` — no absolute/user-specific paths hardcoded in bundled files, and no residual `plugins/sdlc/` path references in the vendored scripts. Expected: pass / exit 0.
- [ ] **[platform-engineer]** Verify all edited/created JSON is valid: `jq -e '.' plugins/gtm/.claude-plugin/plugin.json plugins/gtm/hooks/hooks.json .claude-plugin/marketplace.json`.
- [ ] **[platform-engineer]** Verify shell (when available): `command -v shellcheck >/dev/null && shellcheck plugins/gtm/scripts/*.sh plugins/gtm/hooks/*.sh || echo "shellcheck not installed — bash -n syntax checks (Task Groups 1 & 3) stand in"`.
- [ ] **[platform-engineer]** Verify no residual sdlc path leakage anywhere in the new package: `! grep -rn "plugins/sdlc" plugins/gtm/` (expect empty — gtm is standalone).

---

## Self-review (against spec)

- **AC-1** (Postiz gate stops, writes nothing) → Task Group 4 (`postiz-verify.md`) + TG5 Step 2.
- **AC-2** (product detection + interview gap-fill) → TG4 (`product-detect.md`) + TG5 Steps 3–4.
- **AC-3** (writes `marketing-context.md`, `.agents/product-marketing.md`, `docs/gtm/` scaffold) → TG5 Steps 4–5.
- **AC-4** (re-run offers keep/merge/rerun, never silent overwrite) → TG5 Step 0.
- **AC-5** (committable version-controlled foundation) → TG5 Step 5 (repo-path writes) + Step 6 (commit guidance).
- **Deliverables table** — every `plugins/gtm/` file mapped: plugin.json (TG2), init.md (TG5), product-marketing-manager.md (TG6), hooks.json + load-marketing-context.sh (TG3), 4 vendored scripts (TG1), 3 refs + docs-gtm-readme-template (TG4), README.md (TG7). marketplace.json modification (TG2).
- **Removed deliverable** `refs/agent-binding-template.md` confirmed NOT authored (TG4 verify).
- **No superpowers / no sdlc dependency** enforced in TG2 verify and TG8 grep.

## Return handoff

Plan saved to `docs/superpowers/plans/NA-3.md`. Two execution options:
1. **Subagent-Driven (recommended)** — fresh subagent per task group, review between groups.
2. **Inline Execution** — execute in-session with checkpoints.
