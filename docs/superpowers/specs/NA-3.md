# Bootstrap gtm plugin config via /gtm:init — Technical Spec

**Story:** [NA-3](https://whimzylive.atlassian.net/browse/NA-3) — Bootstrap gtm plugin config via /gtm:init
**Epic:** [NA-2](https://whimzylive.atlassian.net/browse/NA-2) — GTM marketing plugin for nightshift marketplace
**Date:** 2026-07-07

## Overview

Stand up the new `gtm` plugin package and its `/gtm:init` entry command — the marketing counterpart to sdlc's `/init`. `/gtm:init` gates on Postiz reachability, detects the repo's product info (running the product-marketing interview to fill gaps), then writes a version-controlled marketing foundation before any channel or KPI configuration exists.

## Context & Scope Boundary

`gtm` is nightshift's second plugin, sitting beside `sdlc` (`plugins/sdlc/`). NA-3 is the foundation story for the whole Epic — it **blocks** NA-4, NA-5, NA-6, NA-7, NA-8, and NA-11. Those downstream stories own channel ownership/voice/cadence, KPI metric+source setup, engagement listening, pulse, and launch. This spec delivers only:

1. The `gtm` **plugin package** (manifest + marketplace registration + the SessionStart hook that later commands depend on).
2. The **`/gtm:init` command** and the refs it consumes.
3. The **runtime artifacts** `/gtm:init` produces in a consumer repo.

Everything a downstream story owns — Postiz channel config, KPI provider catalogue, engagement providers, pulse loop, launch campaign — is explicitly **out of scope** (see Out of Scope). `/gtm:init` writes the *foundation those stories extend*, not their config.

**This is a plugin/tooling repo** (Markdown + Shell). There is no database, HTTP API, web UI, mobile app, or offline-sync layer in scope — those template sections are omitted per the writing-specs skill.

## Deliverables — Plugin Machinery (committed under `plugins/gtm/`)

Mirror the `plugins/sdlc/` layout exactly. New files:

| File | Purpose |
| ---- | ------- |
| `plugins/gtm/.claude-plugin/plugin.json` | Plugin manifest — `name: "gtm"`, `version`, `description`, `author`, and the `superpowers@claude-plugins-official` cross-marketplace dependency (same as sdlc). No hard dependency on the `sdlc` plugin. |
| `plugins/gtm/commands/init.md` | The `/gtm:init` command (primary deliverable — command namespace derives from plugin name → invoked as `/gtm:init`). |
| `plugins/gtm/agents/product-marketing.md` | Bundled `product-marketing` agent definition — the interviewer dispatched to fill product-info gaps. |
| `plugins/gtm/hooks/hooks.json` | SessionStart hook registration (points at the loader below); SessionEnd → reuse `cleanup-tmp.sh` pattern. |
| `plugins/gtm/hooks/load-marketing-context.sh` | SessionStart loader: (a) writes the `.claude/.gtm-plugin-root` marker so subagents/later commands can resolve `${CLAUDE_PLUGIN_ROOT}`; (b) injects `.claude/project/marketing-context.md` as additionalContext when present. Inert-safe (emits nothing, exit 0) in a repo without gtm config. Modeled on `plugins/sdlc/hooks/load-project-context.sh`. |
| `plugins/gtm/refs/postiz-verify.md` | The Postiz reachability + auth probe protocol (see Postiz Verification). |
| `plugins/gtm/refs/product-detect.md` | The read-only product-info detection procedure (see Product Info Detection). |
| `plugins/gtm/refs/marketing-context-template.md` | The `marketing-context.md` token template `/gtm:init` fills. |
| `plugins/gtm/README.md` | Plugin readme (mirror `plugins/sdlc/README.md` structure). |

Modified file:

| File | Change |
| ---- | ------ |
| `.claude-plugin/marketplace.json` | Append a second entry to `plugins`: `{ "name": "gtm", "source": "./plugins/gtm", "description": "..." }`. Leave the existing `sdlc` entry untouched. |

## Runtime Artifacts Produced by `/gtm:init`

These are **not** committed to the plugin — they are what the command writes into the consumer repo (for the nightshift dogfood, this repo). All are version-controllable so the founder can commit the marketing foundation (AC-5).

### `.claude/project/marketing-context.md` (the config root)

The gtm counterpart to `.claude/project/project-context.md`. Written from `refs/marketing-context-template.md`, no placeholder tokens remaining. Schema:

| Section | Field | Type | Required | Default | Notes |
| ------- | ----- | ---- | -------- | ------- | ----- |
| Product | `name` | string | Yes | — | Detected or interviewed |
| Product | `one-liner` | string | Yes | — | Tagline / one-sentence pitch |
| Product | `repo` | string (URL or `owner/name`) | Yes | — | From `git remote` or interview |
| Product | `landing URL` | string (URL) | No | empty | Blank allowed if none exists yet |
| Postiz  | `backend URL` | string (URL) | Yes | `https://api.postiz.com` | Cloud default; self-hosted override |
| Postiz  | `API key env var` | string (env var **name**) | Yes | `POSTIZ_API_KEY` | Stores the **name only** — never the key value |
| Voice   | `voice overrides` | markdown block | No | empty | Placeholder for per-project ECC anti-slop overrides layered on the plugin defaults; populated by a downstream story, empty at init |

**Hard rule:** the API **key value is never written to disk** — only the env var name is stored. Reachability uses the live env var at run time.

### `.agents/product-marketing.md` (repo-root agent binding)

Per-repo binding/override for the bundled `product-marketing` agent, written at the **repo root** under `.agents/` (as stated verbatim in AC-3 — a gtm convention distinct from sdlc's `.claude/project/agents/`). Carries the resolved product context and points at the bundled agent definition. No placeholder tokens remain after write.

### `docs/gtm/` scaffold

Create the marketing working-directory skeleton:

| Path | Purpose |
| ---- | ------- |
| `docs/gtm/README.md` | Explains the gtm working directory and what downstream stories populate |
| `docs/gtm/digests/.gitkeep` | Reserved for committed pulse digests (Epic: digests committed under `docs/gtm/digests/`) |

Only the skeleton — the content log (JSONL), campaigns, and digests themselves are produced by downstream stories, not by init.

### `.claude/.gtm-plugin-root` (gitignored marker)

Single-line absolute plugin root, written by the SessionStart hook so later gtm commands/subagents resolve `${CLAUDE_PLUGIN_ROOT}`. `/gtm:init` must ensure `.tmp/` and `.claude/.gtm-plugin-root` are gitignored (idempotent append, mirror sdlc Step 4e).

## Command Surface — `/gtm:init`

### Invocation

`/gtm:init` — always interactive. `$ARGUMENTS` is ignored. Command frontmatter carries a `description:` line (mirror `plugins/sdlc/commands/init.md`). Runs **in strict order, top to bottom, STOP at the first failure** with an actionable message — a failed prerequisite must never leave half-written config.

### Execution order

| Step | Name | Behaviour |
| ---- | ---- | --------- |
| 0 | Re-init guard | Detect existing `.claude/project/marketing-context.md`; branch to the Re-run Safety flow if present. |
| 1 | Postiz prerequisite gate | Verify env var present **and** reachability/auth probe passes. STOP with a clear message and **write nothing** on failure (AC-1). |
| 2 | Product info detection | Read-only scan of the repo for name, one-liner, repo, landing URL (AC-2). |
| 3 | Gap interview | If any product-marketing context is missing, dispatch/run the `product-marketing` interview to fill only the gaps (AC-2). |
| 4 | Write artifacts | Write `marketing-context.md`, `.agents/product-marketing.md`, the `docs/gtm/` scaffold, the `.gtm-plugin-root` marker, and ensure gitignore entries (AC-3, AC-5). No placeholder tokens remain. |
| 5 | Post-init checklist | Print what was written, the env var the founder must keep set, and how to commit the foundation; point at the next command (channel/KPI setup). |
| Final | Release session | Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` as the last action (silent no-op outside the worker). Reuse the sdlc script path or vendor an equivalent — see Open Questions. |

## Postiz Verification (Step 1 detail)

Spec'd in `refs/postiz-verify.md`. Two conditions, both required to pass; either failure = STOP, no files written:

1. **Env var present** — the env var named by `API key env var` (default `POSTIZ_API_KEY`) is set and non-empty in the environment.
2. **Reachability + auth probe** — a single lightweight authenticated GET against `<backend URL>` returns a 2xx. A 401/403 means bad/expired key; a connection error means unreachable backend. Each maps to a distinct STOP message.

Backend URL resolution: default `https://api.postiz.com` (cloud); a self-hosted URL may be supplied via prompt or an existing `marketing-context.md` value. The probe reads the key from the env var at run time — the key is never persisted.

## Product Info Detection (Step 2 detail)

Spec'd in `refs/product-detect.md`. Read-only; writes nothing. Resolve each field by first matching source; anything unresolved becomes an interview gap:

| Field | Detection sources (in order) | Interview fallback |
| ----- | ---------------------------- | ------------------ |
| name | `package.json` `name` → git remote repo name → top-level `README.md` H1 | prompt |
| one-liner | `package.json` `description` → README tagline/subtitle → `brand/BRAND_KIT.md` tagline (when present) | prompt |
| repo | `git remote get-url origin` (normalized to `owner/name` or URL) | prompt |
| landing URL | `package.json` `homepage` → first external link/badge in `README.md` | prompt (blank allowed) |

`brand/` is **read-only** here (a detection source); this story makes no changes under `brand/`.

## Product-Marketing Interview (Step 3 detail)

The bundled `product-marketing` agent (`plugins/gtm/agents/product-marketing.md`) fills only the fields detection could not resolve. Prompt one field at a time (never a wall of prompts), offering any detected value as the default. Finite-choice fields (none required for the four product fields today) would use `AskUserQuestion`; the four product fields are free-text prompts. The interview is skipped entirely when detection resolved every required field.

## Re-run Safety (Step 0 detail)

When `.claude/project/marketing-context.md` already exists, **never silently overwrite** (AC-4). Present an `AskUserQuestion` (mirror sdlc `/init` Step 0):

- **Keep existing** — print a summary of current config and STOP; write nothing.
- **Merge new findings** — re-run detection; backfill only template fields absent from the existing file (prompting for missing user-choice fields), preserving every value already set; then write.
- **Re-run full setup** — walk all prompts again with existing values offered as defaults, then rewrite.

## Implementation Guide — platform-engineer

`platform-engineer` owns `plugins/` and `tools/` and is the **only** active agent needed for this story. `web-engineer` (owns `brand/`) is **not** required — `brand/` is read-only detection input.

1. Create the `plugins/gtm/` package skeleton mirroring `plugins/sdlc/` (manifest, `commands/`, `agents/`, `hooks/`, `refs/`, `README.md`).
2. Author `plugins/gtm/commands/init.md` implementing Steps 0–5 + Final above. Use `plugins/sdlc/commands/init.md` as the structural reference (re-init guard, prerequisite gate, read-only scan, one-question-at-a-time prompts, no-placeholder write rule, session-complete release).
3. Author the three refs (`postiz-verify.md`, `product-detect.md`, `marketing-context-template.md`) and the bundled `product-marketing` agent.
4. Author `hooks/hooks.json` + `hooks/load-marketing-context.sh` mirroring sdlc's SessionStart loader, using a `.claude/.gtm-plugin-root` marker (distinct filename so gtm and sdlc markers never collide).
5. Register the plugin in `.claude-plugin/marketplace.json`.
6. Portability: run `tools/portability-lint.sh` — no absolute/user-specific paths hardcoded in bundled files.

## Error Handling

| Scenario | Behaviour |
| -------- | --------- |
| Postiz API key env var missing/empty | STOP; message names the exact env var; write nothing (AC-1). |
| Postiz backend unreachable (connection error) | STOP; message names the backend URL; write nothing. |
| Postiz auth rejected (401/403) | STOP; message says key invalid/expired; write nothing. |
| No `git remote origin` | `repo` becomes an interview gap; prompt for it. |
| No landing URL found | Field left blank (not required); no prompt needed unless founder wants one. |
| Existing config + "Keep existing" | Print summary, STOP, no writes. |
| Existing config + "Merge" / "Re-run" | Backfill or rewrite per Re-run Safety; never clobber set values silently. |
| Any Step failing after Step 1 passes | STOP with actionable message; do not leave a partially-written config set. |

## Permissions & Trust Posture

No RBAC model exists in this repo — the only actor is the founder running `/gtm:init` locally. There is no multi-role permission table to fill. Channel automation posture (draft/auto/manual, human-approval gates) is a downstream-story concern and out of scope here.

## Out of Scope

- Channel ownership / voice / cadence configuration (downstream story — NA-3 blocks it).
- KPI metric and source setup, provider catalogue, and the KPI verification probe (downstream story — the Epic's "Init orchestrates KPI setup" is realized by a separate story that this one unblocks).
- Engagement-listening provider config.
- Pulse loop, launch campaign, demo pipeline, digests content.
- The append-only JSONL content log and its dedupe/merge rules.
- Any change under `brand/` (read-only detection source only).
- Postiz **channel connection** — init verifies the backend is reachable and authenticated; it does not connect or configure individual channels.

## Open Questions

- [ ] **`marketing-context.md` location** — Suggested default: `.claude/project/marketing-context.md` (mirrors `project-context.md`; auto-loaded by the SessionStart hook). Alternative considered: `docs/gtm/`.
- [ ] **`.agents/` vs `.claude/project/agents/` for the agent binding** — Suggested default: follow AC-3 literally → repo-root `.agents/product-marketing.md`. Flag if alignment with sdlc's `.claude/project/agents/` is preferred.
- [ ] **Postiz probe endpoint** — Suggested default: a lightweight authenticated GET against the Postiz public API (e.g. the connected-integrations list) under `<backend URL>`; confirm the exact path against current Postiz API docs during implementation. Only the 2xx-vs-401/403-vs-connection-error distinction is load-bearing for this spec.
- [ ] **`session-complete.sh` reuse** — Suggested default: call the existing `plugins/sdlc/scripts/session-complete.sh` via the resolved sdlc plugin root; if gtm must be standalone with no sdlc dependency, vendor an equivalent script into `plugins/gtm/scripts/`.
- [ ] **Plugin version** — Suggested default: start `plugins/gtm/.claude-plugin/plugin.json` at `0.1.0` (independent of sdlc's version line).
