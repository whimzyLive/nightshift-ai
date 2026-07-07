# Bootstrap gtm plugin config via /gtm:init — Technical Spec

**Story:** [NA-3](https://whimzylive.atlassian.net/browse/NA-3) — Bootstrap gtm plugin config via /gtm:init
**Epic:** [NA-2](https://whimzylive.atlassian.net/browse/NA-2) — GTM marketing plugin for nightshift marketplace
**Date:** 2026-07-07

## Overview

Stand up the new `gtm` plugin package and its `/gtm:init` entry command — the marketing counterpart to sdlc's `/init`. `/gtm:init` gates on Postiz reachability, detects the repo's product info (running the product-marketing interview to fill gaps), then writes a version-controlled marketing foundation before any channel or KPI configuration exists.

## Acceptance Criteria

Binary done/not-done statements (from the NA-3 Jira story). Every `AC-n` reference elsewhere in this spec points here:

- **AC-1** — `/gtm:init` verifies Postiz is reachable (backend URL resolved **and** the API-key env var present) and **stops with a clear message, writing no partial config**, when either check fails.
- **AC-2** — `/gtm:init` detects product info (name, one-liner, repo, landing URL) from the repository; when product-marketing context is missing, it triggers the product-marketing interview to fill the gaps.
- **AC-3** — `/gtm:init` writes `marketing-context.md`, `.agents/product-marketing.md`, and the `docs/gtm/` scaffold.
- **AC-4** — Re-running `/gtm:init` when config already exists offers keep / merge / rerun and **never silently overwrites**.
- **AC-5** — The founder can commit the resulting config as a version-controlled marketing setup.

## Context & Scope Boundary

`gtm` is nightshift's second plugin, sitting beside `sdlc` (`plugins/sdlc/`). NA-3 is the foundation story for the whole Epic — it **blocks** NA-4, NA-5, NA-6, NA-7, NA-8, and NA-11. Those downstream stories own channel ownership/voice/cadence, KPI metric+source setup, engagement listening, pulse, and launch. This spec delivers only:

1. The `gtm` **plugin package** (manifest + marketplace registration + the SessionStart hook that later commands depend on).
2. The **`/gtm:init` command** and the refs it consumes.
3. The **runtime artifacts** `/gtm:init` produces in a consumer repo.

Everything a downstream story owns — Postiz channel config, KPI provider catalogue, engagement providers, pulse loop, launch campaign — is explicitly **out of scope** (see Out of Scope). `/gtm:init` writes the *foundation those stories extend*, not their config.

**This is a plugin/tooling repo** (Markdown + Shell). There is no database, HTTP API, web UI, mobile app, or offline-sync layer in scope — those template sections are omitted per the writing-specs skill.

### Deviations from the epic design doc

The epic design doc `docs/superpowers/specs/2026-07-07-gtm-plugin-design.md` sketches the broader gtm architecture. NA-3 deliberately deviates on two points, scoped to init:

- **No `marketingskills` plugin dependency in NA-3.** The bundled `product-marketing` agent (`plugins/gtm/agents/product-marketing.md`) stands in as the interviewer; adopting the `marketingskills` plugin is deferred to a later story. This keeps the foundation self-contained.
- **The Postiz gate is a raw authenticated HTTP probe, not an MCP-reachability check.** A direct `curl`-style probe against the Postiz backend is simpler and dependency-free for init; an MCP-based integration path is not required to prove reachability.

The `.agents/product-marketing.md` path is nonetheless kept as-is (per AC-3) so that a future `marketingskills` adoption can bind to the same location without moving files.

## Deliverables — Plugin Machinery (committed under `plugins/gtm/`)

Mirror the `plugins/sdlc/` layout exactly. `gtm` has **no hard dependency on the `sdlc` plugin** — it vendors the **complete** shared script set it needs into its own `scripts/` directory so it is standalone, and every reference resolves via `${CLAUDE_PLUGIN_ROOT}/scripts/…` (never an sdlc path). New files:

| File | Purpose |
| ---- | ------- |
| `plugins/gtm/.claude-plugin/plugin.json` | Plugin manifest — `name: "gtm"`, `version: "0.1.0"`, `description`, `author`, and the `superpowers@claude-plugins-official` cross-marketplace dependency (same as sdlc). **No dependency on the `sdlc` plugin.** |
| `plugins/gtm/commands/init.md` | The `/gtm:init` command (primary deliverable — command namespace derives from plugin name → invoked as `/gtm:init`). |
| `plugins/gtm/agents/product-marketing.md` | Bundled `product-marketing` agent definition — the interviewer dispatched to fill product-info gaps. |
| `plugins/gtm/hooks/hooks.json` | SessionStart hook registration (points at the loader below); SessionEnd → the **vendored** `plugins/gtm/scripts/cleanup-tmp.sh`. |
| `plugins/gtm/hooks/load-marketing-context.sh` | SessionStart loader: (a) writes the `.claude/.gtm-plugin-root` marker so subagents/later commands can resolve `${CLAUDE_PLUGIN_ROOT}`; (b) injects `.claude/project/marketing-context.md` as additionalContext when present. Inert-safe (emits nothing, exit 0) in a repo without gtm config. Modeled on `plugins/sdlc/hooks/load-project-context.sh`. |
| `plugins/gtm/scripts/session-complete.sh` | **Vendored** copy of the session-release script (functional equivalent of `plugins/sdlc/scripts/session-complete.sh`) — so gtm depends on nothing outside its own package. Calls the sibling `session-key.sh`. Invoked by the Release-session step. |
| `plugins/gtm/scripts/cleanup-tmp.sh` | **Vendored** copy of the SessionEnd temp-cleanup script (functional equivalent of `plugins/sdlc/scripts/cleanup-tmp.sh`). Calls the sibling `session-key.sh`. Referenced by `hooks.json`. |
| `plugins/gtm/scripts/tmp-dir.sh` | **Vendored** copy of the session-scoped temp-dir resolver (functional equivalent of `plugins/sdlc/scripts/tmp-dir.sh`). Calls the sibling `session-key.sh`. Used by the atomic-write staging in Step 4. |
| `plugins/gtm/scripts/session-key.sh` | **Vendored** copy of the session-key resolver (functional equivalent of `plugins/sdlc/scripts/session-key.sh`). Sibling dependency of all three scripts above — vendored so a literal copy of them never reaches back into `plugins/sdlc/`. |
| `plugins/gtm/refs/postiz-verify.md` | The Postiz reachability + auth probe protocol (see Postiz Verification). |
| `plugins/gtm/refs/product-detect.md` | The read-only product-info detection procedure (see Product Info Detection). |
| `plugins/gtm/refs/marketing-context-template.md` | The `marketing-context.md` token template `/gtm:init` fills. |
| `plugins/gtm/refs/agent-binding-template.md` | The token template `/gtm:init` fills to write `.agents/product-marketing.md` (the per-repo agent binding). |
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

Per-repo binding/override for the bundled `product-marketing` agent, written at the **repo root** under `.agents/` (as stated verbatim in AC-3 — a gtm convention distinct from sdlc's `.claude/project/agents/`). Filled from `refs/agent-binding-template.md`. Carries the resolved product context and points at the bundled agent definition. No placeholder tokens remain after write.

### `docs/gtm/` scaffold

Create the marketing working-directory skeleton:

| Path | Purpose |
| ---- | ------- |
| `docs/gtm/README.md` | Explains the gtm working directory. Minimal required sections: **(1) Purpose** (what `docs/gtm/` holds); **(2) Directory map** (`digests/` and the placeholders downstream stories add); **(3) What init writes vs what downstream stories populate**. Sourced from a `refs/docs-gtm-readme-template.md` template or written inline by the command. |
| `docs/gtm/digests/.gitkeep` | Reserved for committed pulse digests (Epic: digests committed under `docs/gtm/digests/`) |

Only the skeleton — the content log (JSONL), campaigns, and digests themselves are produced by downstream stories, not by init.

### `.claude/.gtm-plugin-root` (gitignored marker)

Single-line absolute plugin root, written by the SessionStart hook so later gtm commands/subagents resolve `${CLAUDE_PLUGIN_ROOT}`. `/gtm:init` must ensure `.tmp/` and `.claude/.gtm-plugin-root` are gitignored (idempotent append, mirror sdlc Step 4e).

**Note — deliberate divergence from sdlc:** sdlc's `.claude/.sdlc-plugin-root` marker is committed; the gtm marker `.claude/.gtm-plugin-root` is **gitignored**. This is an intentional improvement — the marker is a per-session, machine-absolute cache and should never be committed.

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
| 4 | Write artifacts (atomic) | Stage every write to the session temp dir first, then move all staged files into their final paths only after **all** writes succeed (see Atomic-write requirement). Writes `marketing-context.md`, `.agents/product-marketing.md`, the `docs/gtm/` scaffold, the `.gtm-plugin-root` marker, and ensures gitignore entries (AC-3, AC-5). No placeholder tokens remain. |
| 5 | Post-init checklist | Print what was written, the env var the founder must keep set, and how to commit the foundation; name the follow-up stories/epic that extend this foundation (see Post-init checklist). |
| Final | Release session | Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` (the vendored gtm copy) as the last action — silent no-op outside the worker. |

### Atomic-write requirement (Step 4)

`/gtm:init` must never leave a half-written config set. Stage **all** artifact writes under the session temp dir (resolved via the vendored `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh` → `./.tmp/<session>`), and only **after every staged write succeeds** move them into their final paths (same-filesystem rename where possible). On **any** failure mid-write: delete the staging area and leave the repo **untouched** — no partial `marketing-context.md`, no orphan `.agents/` or `docs/gtm/` files.

### Post-init checklist (Step 5)

The checklist names the concrete follow-up work that extends this foundation — the stories NA-3 blocks, under Epic **NA-2** — rather than any not-yet-existing command name:

- **NA-4 / NA-5 / NA-6 / NA-7 / NA-8** — channel ownership/voice/cadence, KPI metric+source setup, engagement listening, pulse, launch.
- **NA-11** — (as linked from NA-3).

It also reminds the founder to keep the Postiz API-key env var set, and shows how to commit the written foundation (AC-5).

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

**Both Merge and Re-run re-enter at Step 1 (the Postiz gate re-runs before any write).** A dead or unreachable backend can therefore never be re-written against — the gate protects the write path on every path through the command, first-run and re-run alike.

## Implementation Guide — platform-engineer

`platform-engineer` owns `plugins/` and `tools/` and is the **only** active agent needed for this story. `web-engineer` (owns `brand/`) is **not** required — `brand/` is read-only detection input.

1. Create the `plugins/gtm/` package skeleton mirroring `plugins/sdlc/` (manifest, `commands/`, `agents/`, `hooks/`, `scripts/`, `refs/`, `README.md`).
2. Author `plugins/gtm/commands/init.md` implementing Steps 0–5 + Final above. Use `plugins/sdlc/commands/init.md` as the structural reference (re-init guard, prerequisite gate, read-only scan, one-question-at-a-time prompts, no-placeholder write rule, atomic staged writes, session-complete release).
3. Author the four refs (`postiz-verify.md`, `product-detect.md`, `marketing-context-template.md`, `agent-binding-template.md`) and the bundled `product-marketing` agent.
4. Vendor the **complete** script set into `plugins/gtm/scripts/` — `session-complete.sh`, `cleanup-tmp.sh`, `tmp-dir.sh`, **and** their shared sibling `session-key.sh` (functional equivalents of the sdlc scripts) — so gtm is standalone. All three top-level scripts shell out to `session-key.sh`; omitting it would break them or silently reintroduce an sdlc-path dependency. Keep every invocation resolving via `${CLAUDE_PLUGIN_ROOT}/scripts/…`.
5. Author `hooks/hooks.json` + `hooks/load-marketing-context.sh` mirroring sdlc's SessionStart loader, using a `.claude/.gtm-plugin-root` marker (distinct filename so gtm and sdlc markers never collide).
6. Register the plugin in `.claude-plugin/marketplace.json`.
7. Portability: run `tools/portability-lint.sh` — no absolute/user-specific paths hardcoded in bundled files, and no residual `plugins/sdlc/` path references in the vendored scripts.

## Error Handling

| Scenario | Behaviour |
| -------- | --------- |
| Postiz API key env var missing/empty | STOP; message names the exact env var; write nothing (AC-1). |
| Postiz backend unreachable (connection error) | STOP; message names the backend URL; write nothing. |
| Postiz auth rejected (401/403) | STOP; message says key invalid/expired; write nothing. |
| No `git remote origin` | `repo` becomes an interview gap; prompt for it. |
| No landing URL found | Field left blank (not required); no prompt needed unless founder wants one. |
| Existing config + "Keep existing" | Print summary, STOP, no writes. |
| Existing config + "Merge" / "Re-run" | Re-enter at Step 1 (Postiz gate re-runs); then backfill or rewrite per Re-run Safety; never clobber set values silently. |
| Any Step failing after Step 1 passes | STOP with actionable message; **atomic write** guarantees the repo is left untouched — delete the staging area, leave no partially-written config set. |

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
- Adopting the `marketingskills` plugin — deferred; NA-3 uses the bundled `product-marketing` agent (see Deviations).

## Open Questions

- [ ] **Postiz probe endpoint** — Suggested default: a lightweight authenticated GET against the Postiz public API (e.g. the connected-integrations list) under `<backend URL>`; confirm the exact path against current Postiz API docs during implementation. Only the 2xx-vs-401/403-vs-connection-error distinction is load-bearing for this spec.

## Decided (defaults locked by this spec)

- **`marketing-context.md` location — Decided:** `.claude/project/marketing-context.md` (mirrors `project-context.md`; auto-loaded by the SessionStart hook).
- **`.agents/product-marketing.md` path — Decided:** repo-root `.agents/product-marketing.md`, per AC-3 (kept for future `marketingskills` compatibility, see Deviations).
- **Vendored script set — Decided:** gtm has **no** sdlc dependency; vendor the complete set — `session-complete.sh`, `cleanup-tmp.sh`, `tmp-dir.sh`, and the shared sibling `session-key.sh` — into `plugins/gtm/scripts/`, and resolve every call via `${CLAUDE_PLUGIN_ROOT}/scripts/…`.
- **Plugin version — Decided:** `plugins/gtm/.claude-plugin/plugin.json` starts at `0.1.0` (independent of sdlc's version line).
