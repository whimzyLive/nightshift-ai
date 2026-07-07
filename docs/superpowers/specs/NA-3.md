# Bootstrap gtm plugin config via /gtm:init — Technical Spec

**Story:** [NA-3](https://whimzylive.atlassian.net/browse/NA-3) — Bootstrap gtm plugin config via /gtm:init
**Epic:** [NA-2](https://whimzylive.atlassian.net/browse/NA-2) — GTM marketing plugin for nightshift marketplace
**Date:** 2026-07-07

## Overview

Stand up the new `gtm` plugin package and its `/gtm:init` entry command — the marketing counterpart to sdlc's `/init`. Like sdlc's `/init`, `/gtm:init` does **all its own setup work in-command** (no agent dispatch): it installs the Postiz + marketing-skills dependencies, gates on Postiz reachability via the postiz CLI, detects the repo's product info, invokes the marketingskills `product-marketing` skill to create the marketing context doc, and writes a version-controlled marketing foundation before any channel or KPI configuration exists.

## Acceptance Criteria

Binary done/not-done statements (from the NA-3 Jira story). Every `AC-n` reference elsewhere in this spec points here:

- **AC-1** — `/gtm:init` verifies Postiz is reachable (a resolved backend URL, the `POSTIZ_API_KEY` env var present, **and** `postiz auth:status` succeeds against that backend URL) and **stops with a clear message, writing no partial config**, when any check fails.
- **AC-2** — `/gtm:init` detects product info (name, one-liner, repo, landing URL) from the repository; when product-marketing context is missing, it triggers the `product-marketing` interview (the marketingskills `product-marketing` skill) to fill the gaps.
- **AC-3** — `/gtm:init` writes `marketing-context.md`, `.agents/product-marketing.md`, and the `docs/gtm/` scaffold.
- **AC-4** — Re-running `/gtm:init` when config already exists offers keep / merge / rerun and **never silently overwrites**.
- **AC-5** — The founder can commit the resulting config as a version-controlled marketing setup.

## Context & Scope Boundary

`gtm` is nightshift's second plugin, sitting beside `sdlc` (`plugins/sdlc/`). NA-3 is the foundation story for the whole Epic — it **blocks** NA-4, NA-5, NA-6, NA-7, NA-8, and NA-11. Those downstream stories own channel ownership/voice/cadence, KPI metric+source setup, engagement listening, pulse, and launch. This spec delivers only:

1. The `gtm` **plugin package** (manifest + marketplace registration + the Postiz and marketing-skills dependencies + the SessionStart hook that later commands depend on).
2. The **`/gtm:init` command** and the refs it consumes — init performs detection, the product-marketing interview, and all config writes **itself**, in-command.
3. The **runtime artifacts** `/gtm:init` produces in a consumer repo.
4. The **`product-marketing-manager` agent definition** (shipped, not wired into init) — used by downstream brief-producing workflows.

Everything a downstream story owns — Postiz channel config, KPI provider catalogue, engagement providers, pulse loop, launch campaign, **and the GTM-brief-producing workflows that drive the `product-marketing-manager` agent** — is explicitly **out of scope** (see Out of Scope). `/gtm:init` writes the *foundation those stories extend*, not their config.

**This is a plugin/tooling repo** (Markdown + Shell). There is no database, HTTP API, web UI, mobile app, or offline-sync layer in scope — those template sections are omitted per the writing-specs skill.

### Postiz integration — the `postiz@postiz-agent` skill

All Postiz operations across the gtm plugin (init's reachability gate, and every downstream publish/upload/analytics action) go through the **`postiz` skill shipped by the `postiz@postiz-agent` plugin** (`https://github.com/gitroomhq/postiz-agent`, AGPL-3.0). Verified facts:

- It is a Claude Code plugin marketplace: marketplace name **`postiz-agent`**, plugin name **`postiz`** — installable reference **`postiz@postiz-agent`**, marketplace source **`gitroomhq/postiz-agent`**.
- The plugin ships a `postiz` skill (`SKILL.md` at repo root, source `./`) wrapping the `postiz` npm CLI (`npm i -g postiz`): `auth:status` / `auth:login`, `posts:create`, `upload`, `integrations`, `analytics` across 28+ platforms.
- **CLI contract:** requires env var **`POSTIZ_API_URL`** (backend URL) plus the API-key env var **`POSTIZ_API_KEY`** for authentication. gtm treats the backend URL as a **persisted config value** (resolved at init and exported as `POSTIZ_API_URL` before every CLI call) rather than an env-only secret; only the API key stays env-only. *(The CLI also offers OAuth via `postiz auth:login`, but gtm's init gate requires the `POSTIZ_API_KEY` env var — see Postiz Verification — consistent with the `marketing-context.md` schema and the Decided env-var contract.)*
- **Hard rules (from the skill):** authenticate first (`postiz auth:status` must pass before any other command); all media must be uploaded through `postiz upload`.

gtm therefore **never hand-rolls HTTP against Postiz** — it delegates to the CLI/skill.

### Marketing-skills integration — the `marketing-skills@marketingskills` plugin

The marketing craft (product-marketing context, launch planning, content strategy, copywriting/editing, positioning) comes from the **`marketing-skills` plugin** (`https://github.com/coreyhaines31/marketingskills`). Verified facts:

- Claude Code plugin marketplace: marketplace name **`marketingskills`**, plugin name **`marketing-skills`** (v2.6.0), source `./`, **47 skills** under `skills/`.
- Its **`product-marketing` skill** (`skills/product-marketing/`) creates and maintains **`.agents/product-marketing.md`** as the canonical product-context doc every other marketing skill references; it checks legacy locations, and can either **auto-draft from the codebase** (README / landing / `package.json`) or run a **conversational interview**.
- Other skills relevant to the GTM brief: **`launch`**, **`content-strategy`**, **`copywriting`**, **`copy-editing`**, and positioning-related refs.

`/gtm:init` **invokes the `product-marketing` skill directly** to produce `.agents/product-marketing.md` — it does not hand-roll a template or dispatch an agent for this.

### Deviations from the epic design doc

The epic design doc `docs/superpowers/specs/2026-07-07-gtm-plugin-design.md` sketches the broader gtm architecture. NA-3 deliberately deviates on these points, scoped to init:

- **`marketingskills` is adopted in NA-3** (it is no longer deferred). The `marketing-skills@marketingskills` plugin is a hard dependency, and its `product-marketing` skill owns `.agents/product-marketing.md`. **`.agents/product-marketing.md` is literally the file the marketingskills `product-marketing` skill expects and maintains — that is exactly why AC-3 places it at the repo root.** The bundled `product-marketing-manager` agent (below) uses these skills; it does not reimplement them.
- **The Postiz reachability gate goes through the `postiz` skill/CLI (`postiz auth:status`), not a raw authenticated HTTP probe.** *(This supersedes the earlier "raw authenticated HTTP probe" deviation — that approach is no longer used.)* The CLI owns endpoint, transport, and auth details; init only interprets its exit/status.
- **`/gtm:init` owns all setup work in-command** — detection, the product-marketing interview (via the skill), and every config write happen inside the command, mirroring sdlc's `/init`. Init does not dispatch a setup agent.

## Deliverables — Plugin Machinery (committed under `plugins/gtm/`)

Mirror the `plugins/sdlc/` layout exactly. `gtm` has **no hard dependency on the `sdlc` plugin** — it vendors the **complete** shared script set it needs into its own `scripts/` directory so it is standalone, and every reference resolves via `${CLAUDE_PLUGIN_ROOT}/scripts/…` (never an sdlc path). It **does** depend on `postiz@postiz-agent` (Postiz ops) and `marketing-skills@marketingskills` (marketing craft), both declared in the manifest and allowlisted in the marketplace. New files:

| File | Purpose |
| ---- | ------- |
| `plugins/gtm/.claude-plugin/plugin.json` | Plugin manifest — `name: "gtm"`, `version: "0.1.0"`, `description`, `author`, and a `dependencies` array with **two** entries: **`postiz@postiz-agent`** (Postiz skill) and **`marketing-skills@marketingskills`** (marketing skills). **No `superpowers` dependency** — nothing in gtm invokes a superpowers skill. **No dependency on the `sdlc` plugin.** |
| `plugins/gtm/commands/init.md` | The `/gtm:init` command (primary deliverable — command namespace derives from plugin name → invoked as `/gtm:init`). Performs detection, the product-marketing interview (by invoking the marketingskills `product-marketing` skill), and all config writes in-command. |
| `plugins/gtm/agents/product-marketing-manager.md` | Bundled **`product-marketing-manager` (PMM)** agent definition — the marketing mirror of sdlc's `product-manager`. Takes a vague marketing request / product context → a **GTM brief** (positioning, messaging, target audience, channel rationale, launch angle), using the marketingskills skills (`product-marketing` for context; `launch` / `content-strategy` / `copywriting` as needed) and the `postiz` skill for any Postiz operation (**never raw HTTP**). Brief output convention: `docs/gtm/briefs/<date>-<slug>.md`. **NA-3 ships the definition only; brief-producing workflows are downstream (NA-4..NA-8, NA-11).** |
| `plugins/gtm/hooks/hooks.json` | SessionStart hook registration (points at the loader below); SessionEnd → the **vendored** `plugins/gtm/scripts/cleanup-tmp.sh`. |
| `plugins/gtm/hooks/load-marketing-context.sh` | SessionStart loader: (a) writes the `.claude/.gtm-plugin-root` marker so subagents/later commands can resolve `${CLAUDE_PLUGIN_ROOT}`; (b) injects `.claude/project/marketing-context.md` as additionalContext when present. Inert-safe (emits nothing, exit 0) in a repo without gtm config. Modeled on `plugins/sdlc/hooks/load-project-context.sh`. |
| `plugins/gtm/scripts/session-complete.sh` | **Vendored** copy of the session-release script (functional equivalent of `plugins/sdlc/scripts/session-complete.sh`) — so gtm depends on nothing outside its own package. Calls the sibling `session-key.sh`. Invoked by the Release-session step. |
| `plugins/gtm/scripts/cleanup-tmp.sh` | **Vendored** copy of the SessionEnd temp-cleanup script (functional equivalent of `plugins/sdlc/scripts/cleanup-tmp.sh`). Calls the sibling `session-key.sh`. Referenced by `hooks.json`. |
| `plugins/gtm/scripts/tmp-dir.sh` | **Vendored** copy of the session-scoped temp-dir resolver (functional equivalent of `plugins/sdlc/scripts/tmp-dir.sh`). Calls the sibling `session-key.sh`. Used by the atomic-write staging in Step 5. |
| `plugins/gtm/scripts/session-key.sh` | **Vendored** copy of the session-key resolver (functional equivalent of `plugins/sdlc/scripts/session-key.sh`). Sibling dependency of all three scripts above — vendored so a literal copy of them never reaches back into `plugins/sdlc/`. |
| `plugins/gtm/refs/postiz-verify.md` | The Postiz reachability/auth gate protocol, expressed via the `postiz` CLI (`postiz auth:status`) — see Postiz Verification. |
| `plugins/gtm/refs/product-detect.md` | The read-only product-info detection procedure (see Product Info Detection). |
| `plugins/gtm/refs/marketing-context-template.md` | The `marketing-context.md` token template `/gtm:init` fills. (This is gtm's own plugin-config file — distinct from `.agents/product-marketing.md`, which the marketingskills skill owns.) |
| `plugins/gtm/README.md` | Plugin readme (mirror `plugins/sdlc/README.md` structure); documents the two dependencies and the `POSTIZ_API_URL` / `POSTIZ_API_KEY` env-var contract. |

> **Removed vs earlier draft:** `refs/agent-binding-template.md` is **not** a deliverable. `.agents/product-marketing.md` is created and maintained by the marketingskills `product-marketing` skill, which owns that file's format — init invokes the skill rather than filling a gtm template.

Modified file:

| File | Change |
| ---- | ------ |
| `.claude-plugin/marketplace.json` | Two edits: **(1)** append a `gtm` entry to `plugins`: `{ "name": "gtm", "source": "./plugins/gtm", "description": "..." }` (leave the `sdlc` entry untouched). **(2)** add `"postiz-agent"` **and** `"marketingskills"` to `allowCrossMarketplaceDependenciesOn` so gtm's **two** cross-marketplace dependencies resolve (result: `["claude-plugins-official", "postiz-agent", "marketingskills"]`). The pre-existing `claude-plugins-official` entry **stays for sdlc's superpowers dependency** — gtm itself does not need it. |

## Runtime Artifacts Produced by `/gtm:init`

These are **not** committed to the plugin — they are what the command writes into the consumer repo (for the nightshift dogfood, this repo). All are version-controllable so the founder can commit the marketing foundation (AC-5).

### `.claude/project/marketing-context.md` (gtm plugin config)

The gtm counterpart to `.claude/project/project-context.md` — it exists to **customise gtm plugin behaviour exactly as `project-context.md` customises sdlc**. Written **by init, in-command**, from `refs/marketing-context-template.md`, no placeholder tokens remaining. Distinct from `.agents/product-marketing.md` (the marketingskills product-context doc): this file holds gtm's operational config (product basics, Postiz env-var contract, voice overrides) and points at `.agents/product-marketing.md` as the canonical product-marketing detail. Schema:

| Section | Field | Type | Required | Default | Notes |
| ------- | ----- | ---- | -------- | ------- | ----- |
| Product | `name` | string | Yes | — | Detected or interviewed |
| Product | `one-liner` | string | Yes | — | Tagline / one-sentence pitch |
| Product | `repo` | string (URL or `owner/name`) | Yes | — | From `git remote` or interview |
| Product | `landing URL` | string (URL) | No | empty | Blank allowed if none exists yet |
| Postiz  | `Backend URL` | string (URL) | Yes | `https://api.postiz.com` | Stores the **resolved value** — chosen at init via `AskUserQuestion` (cloud default or self-hosted); not a secret. Exported as `POSTIZ_API_URL` by commands invoking the `postiz` CLI. |
| Postiz  | `API key env var` | string (env var **name**) | Yes | `POSTIZ_API_KEY` | Stores the **name only** — never the key value |
| Voice   | `voice overrides` | markdown block | No | empty | Placeholder for per-project ECC anti-slop overrides layered on the plugin defaults; populated by a downstream story, empty at init |

**Hard rule — secret hygiene:** the Postiz **backend URL is persisted by design** — it is a
non-secret config value, chosen at init and written as the `Backend URL` token; commands invoking
the `postiz` CLI export it as `POSTIZ_API_URL`. Only the **API key** stays env-only: its env-var
**name** (`POSTIZ_API_KEY`) is persisted, but the key **value lives in the environment and is
never written to disk**.

### `.agents/product-marketing.md` (marketingskills canonical product-context doc)

The canonical product-context document that every marketingskills skill references, written at the **repo root** under `.agents/` — the exact location the marketingskills `product-marketing` skill expects (which is **why** AC-3 places it there). **Created and maintained by the marketingskills `product-marketing` skill**, not by a gtm template: `/gtm:init` invokes that skill (Step 4), seeding it with the Step-3 detection so it auto-drafts from README / landing / `package.json`, then the founder corrects; or the skill runs a from-scratch conversational interview when nothing is detected. Init verifies the file exists after the skill runs (Step 5) and treats it as the skill's own output.

### `docs/gtm/` scaffold

Create the marketing working-directory skeleton:

| Path | Purpose |
| ---- | ------- |
| `docs/gtm/README.md` | Explains the gtm working directory. Minimal required sections: **(1) Purpose** (what `docs/gtm/` holds); **(2) Directory map** (`digests/`, `briefs/`, and the placeholders downstream stories add); **(3) What init writes vs what downstream stories populate**. Sourced from a `refs/docs-gtm-readme-template.md` template or written inline by the command. |
| `docs/gtm/digests/.gitkeep` | Reserved for committed pulse digests (Epic: digests committed under `docs/gtm/digests/`) |
| `docs/gtm/briefs/.gitkeep` | Reserved for GTM briefs the `product-marketing-manager` agent emits (`docs/gtm/briefs/<date>-<slug>.md`); the briefs themselves are produced by downstream workflows, not init |

Only the skeleton — the content log (JSONL), campaigns, digests, and briefs themselves are produced by downstream stories, not by init.

### `.claude/.gtm-plugin-root` (gitignored marker)

Single-line absolute plugin root, written by the SessionStart hook so later gtm commands/subagents resolve `${CLAUDE_PLUGIN_ROOT}`. `/gtm:init` must ensure `.tmp/` and `.claude/.gtm-plugin-root` are gitignored (idempotent append, mirror sdlc Step 4e).

**Note — deliberate divergence from sdlc:** sdlc's `.claude/.sdlc-plugin-root` marker is committed; the gtm marker `.claude/.gtm-plugin-root` is **gitignored**. This is an intentional improvement — the marker is a per-session, machine-absolute cache and should never be committed.

## Command Surface — `/gtm:init`

### Invocation

`/gtm:init` — always interactive. `$ARGUMENTS` is ignored. Command frontmatter carries a `description:` line (mirror `plugins/sdlc/commands/init.md`). Runs **in strict order, top to bottom, STOP at the first failure** with an actionable message — a failed prerequisite must never leave half-written config. All steps run **in-command** (no agent dispatch); Step 4 invokes the marketingskills `product-marketing` **skill**.

### Execution order

| Step | Name | Behaviour |
| ---- | ---- | --------- |
| 0 | Re-init guard | Detect existing `.claude/project/marketing-context.md`; branch to the Re-run Safety flow if present. |
| 1 | Dependency check | Verify **both** the `postiz@postiz-agent` plugin (+ `postiz` skill) **and** the `marketing-skills@marketingskills` plugin (+ `product-marketing` skill) are installed. If missing, install (`claude plugin marketplace add <src>` → `claude plugin install <plugin>@<marketplace> --scope project`) or instruct the user; STOP with an actionable message if either cannot be installed. Writes no config. |
| 2 | Postiz prerequisite gate | Resolve the backend URL (existing `marketing-context.md` token → `POSTIZ_API_URL` env as seed → `AskUserQuestion` cloud default/self-hosted), verify `POSTIZ_API_KEY` is present, **and** `postiz auth:status` reports authenticated against the resolved backend. STOP with a clear message and **write nothing** on failure (AC-1). |
| 3 | Product info detection | In-command, read-only scan of the repo for name, one-liner, repo, landing URL (AC-2). |
| 4 | Product-marketing context | In-command: **invoke the marketingskills `product-marketing` skill** to create/maintain `.agents/product-marketing.md`, seeded with the Step-3 detection (auto-draft → founder-corrects, or from-scratch interview). No agent dispatch (AC-2, AC-3). |
| 5 | Write gtm config (atomic) | In-command: stage init's own writes to the session temp dir first, then move them into place only after **all** succeed (see Atomic-write requirement). Writes `marketing-context.md`, the `docs/gtm/` scaffold, the `.gtm-plugin-root` marker, and ensures gitignore entries; then **verifies `.agents/product-marketing.md` exists** (produced by Step 4) — STOP if absent (AC-3, AC-5). No placeholder tokens remain. |
| 6 | Post-init checklist | Print what was written, the env vars the founder must keep set, and how to commit the foundation; name the follow-up stories/epic that extend this foundation (see Post-init checklist). |
| Final | Release session | Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` (the vendored gtm copy) as the last action — silent no-op outside the worker. |

### Dependency check (Step 1 detail)

`/gtm:init` confirms both dependency plugins/skills are available before any reachability check:

- **Present** → continue to Step 2.
- **Missing** → install idempotently, one per plugin: `claude plugin marketplace add gitroomhq/postiz-agent` → `claude plugin install postiz@postiz-agent --scope project`, and `claude plugin marketplace add coreyhaines31/marketingskills` → `claude plugin install marketing-skills@marketingskills --scope project` (project scope records them in `.claude/settings.json` `enabledPlugins`, committed, so teammates get them on checkout). If the environment cannot install one, STOP with instructions (the manifest declares both dependencies, so a normal `/plugin install gtm@nightshift` also pulls them via the marketplace allowlist).

### Atomic-write requirement (Step 5)

`/gtm:init` must never leave a half-written **gtm config** set. Stage init's own writes (`marketing-context.md`, the `docs/gtm/` scaffold, the `.gtm-plugin-root` marker) under the session temp dir (resolved via the vendored `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh` → `./.tmp/<session>`), and only **after every staged write succeeds** move them into their final paths (same-filesystem rename where possible). On **any** failure mid-write: delete the staging area and leave init's config paths **untouched** — no partial `marketing-context.md`, no orphan `docs/gtm/` files.

**Scope of the guarantee (simpler consistent stance):** the atomic staging covers only init's **own** writes. `.agents/product-marketing.md` is the marketingskills skill's **own interactive output** (Step 4) — it is accepted as the skill's output, **not** staged by init. Because that skill is idempotent (it checks legacy locations and re-maintains the file on every invocation), a file left from a Step-5 failure is safely reconciled on the next run (Merge / Re-run). Init's role for that file is limited to verifying it exists before finalizing.

### Post-init checklist (Step 6)

The checklist names the concrete follow-up work that extends this foundation — the stories NA-3 blocks, under Epic **NA-2** — rather than any not-yet-existing command name:

- **NA-4 / NA-5 / NA-6 / NA-7 / NA-8** — channel ownership/voice/cadence, KPI metric+source setup, engagement listening, pulse, launch.
- **NA-11** — (as linked from NA-3).

It also reminds the founder to keep the `POSTIZ_API_KEY` env var set (the backend URL now lives in `marketing-context.md`, not the environment), and shows how to commit the written foundation (AC-5).

## Postiz Verification (Step 2 detail)

Spec'd in `refs/postiz-verify.md`. Runs **through the `postiz` skill/CLI** — gtm never hand-rolls HTTP. Three conditions, all required to pass; any failure = STOP, no files written:

1. **Resolve the backend URL** — first match wins: (a) the existing `marketing-context.md` `Backend URL` token, when this is a Merge/Re-run re-entry; (b) `POSTIZ_API_URL` env var, if set — seeds the default answer only, never skips the question; (c) `AskUserQuestion` — founder picks **cloud default** (`https://api.postiz.com`) or **self-hosted** (supplies a URL). Export the resolved value as `POSTIZ_API_URL` for the rest of the session.
2. **API key env var present** — `POSTIZ_API_KEY` is set and non-empty. (The gate requires the API-key env var — consistent with AC-1, the `marketing-context.md` schema, and the Decided env-var contract; the CLI's OAuth mode is not an accepted init-gate path.)
3. **Auth probe** — `postiz auth:status` (with the resolved backend URL exported) reports authenticated. "Not authenticated" (bad/expired/absent key) and a CLI/connection error (unreachable backend) each map to a distinct STOP message; an unresolvable backend URL also maps to its own STOP message.

The CLI owns the endpoint, transport, and auth mechanics; init only interprets `auth:status`. The backend URL is a **persisted config value** (written to `marketing-context.md`'s `Backend URL` token in Step 5; authoritative for future sessions over a stale env var) — only the API key stays env-only, and only its env-var **name** is ever written to `marketing-context.md`.

## Product Info Detection (Step 3 detail)

Spec'd in `refs/product-detect.md`. In-command, read-only; writes nothing. Resolve each field by first matching source; anything unresolved becomes an interview gap that Step 4's skill invocation fills:

| Field | Detection sources (in order) | Interview fallback |
| ----- | ---------------------------- | ------------------ |
| name | `package.json` `name` → git remote repo name → top-level `README.md` H1 | prompt |
| one-liner | `package.json` `description` → README tagline/subtitle → `brand/BRAND_KIT.md` tagline (when present) | prompt |
| repo | `git remote get-url origin` (normalized to `owner/name` or URL) | prompt |
| landing URL | `package.json` `homepage` → first external link/badge in `README.md` | prompt (blank allowed) |

`brand/` is **read-only** here (a detection source); this story makes no changes under `brand/`. The detection result seeds both Step 4 (the skill's auto-draft of `.agents/product-marketing.md`) and Step 5 (init's `marketing-context.md` product fields).

## Product-Marketing Interview (Step 4 detail)

`/gtm:init` **invokes the marketingskills `product-marketing` skill in-command** — it does **not** dispatch an agent. The skill owns `.agents/product-marketing.md`: seeded with the Step-3 detection it auto-drafts the doc from README / landing page / `package.json`, then the founder corrects it; when nothing is detected it runs a from-scratch conversational interview. The skill also checks legacy locations before writing. Init passes the detected product info to the skill and, on completion, proceeds to Step 5 (which verifies the file exists). This interview needs no Postiz calls.

## Re-run Safety (Step 0 detail)

When `.claude/project/marketing-context.md` already exists, **never silently overwrite** (AC-4). Present an `AskUserQuestion` (mirror sdlc `/init` Step 0):

- **Keep existing** — print a summary of current config and STOP; write nothing.
- **Merge new findings** — re-run detection; backfill only template fields absent from the existing file (prompting for missing user-choice fields), preserving every value already set; then write. `.agents/product-marketing.md` is re-maintained idempotently by the marketingskills skill.
- **Re-run full setup** — walk all prompts again with existing values offered as defaults, then rewrite.

**Both Merge and Re-run re-enter at Steps 1–2 (the dependency check and the Postiz gate re-run before any write).** A dead or unreachable backend can therefore never be re-written against — the checks protect the write path on every path through the command, first-run and re-run alike.

## Implementation Guide — platform-engineer

`platform-engineer` owns `plugins/` and `tools/` and is the **only** active agent needed for this story. `web-engineer` (owns `brand/`) is **not** required — `brand/` is read-only detection input.

1. Create the `plugins/gtm/` package skeleton mirroring `plugins/sdlc/` (manifest, `commands/`, `agents/`, `hooks/`, `scripts/`, `refs/`, `README.md`).
2. Declare the two dependencies: in `plugins/gtm/.claude-plugin/plugin.json` add `postiz@postiz-agent` and `marketing-skills@marketingskills` to `dependencies` (**no `superpowers`**, **no `sdlc`**); in `.claude-plugin/marketplace.json` add `"postiz-agent"` and `"marketingskills"` to `allowCrossMarketplaceDependenciesOn` (the pre-existing `claude-plugins-official` entry stays for sdlc, not gtm) and append the `gtm` plugin entry.
3. Author `plugins/gtm/commands/init.md` implementing Steps 0–6 + Final above — all setup runs in-command (no agent dispatch). Use `plugins/sdlc/commands/init.md` as the structural reference (re-init guard, prerequisite gate, read-only scan, one-question-at-a-time prompts, no-placeholder write rule, atomic staged writes, session-complete release). Step 1 installs both dependency plugins if absent; Step 2 gates via `postiz auth:status`; Step 4 invokes the marketingskills `product-marketing` skill to produce `.agents/product-marketing.md`.
4. Author the three refs (`postiz-verify.md`, `product-detect.md`, `marketing-context-template.md`). Do **not** author an agent-binding template — the marketingskills `product-marketing` skill owns `.agents/product-marketing.md`.
5. Author the `product-marketing-manager` agent definition (`plugins/gtm/agents/product-marketing-manager.md`): PMM takes a marketing request/product context → a GTM brief (`docs/gtm/briefs/<date>-<slug>.md`) using the marketingskills skills (`product-marketing`, `launch`, `content-strategy`, `copywriting`) and the `postiz` skill (never raw HTTP). Ship the definition only — the brief workflows are downstream.
6. Vendor the **complete** script set into `plugins/gtm/scripts/` — `session-complete.sh`, `cleanup-tmp.sh`, `tmp-dir.sh`, **and** their shared sibling `session-key.sh` (functional equivalents of the sdlc scripts) — so gtm is standalone. All three top-level scripts shell out to `session-key.sh`; omitting it would break them or silently reintroduce an sdlc-path dependency. Keep every invocation resolving via `${CLAUDE_PLUGIN_ROOT}/scripts/…`.
7. Author `hooks/hooks.json` + `hooks/load-marketing-context.sh` mirroring sdlc's SessionStart loader, using a `.claude/.gtm-plugin-root` marker (distinct filename so gtm and sdlc markers never collide).
8. Portability: run `tools/portability-lint.sh` — no absolute/user-specific paths hardcoded in bundled files, and no residual `plugins/sdlc/` path references in the vendored scripts.

## Error Handling

| Scenario | Behaviour |
| -------- | --------- |
| `postiz@postiz-agent` or `marketing-skills@marketingskills` not installed and cannot be installed | STOP; message gives the `claude plugin marketplace add <src>` + `claude plugin install <plugin>@<marketplace>` steps for the missing plugin(s); write nothing. |
| Postiz backend URL cannot be resolved (should not happen — `AskUserQuestion` always yields one) | STOP; message says re-run `/gtm:init` and answer the backend-URL prompt; write nothing (AC-1). |
| `POSTIZ_API_KEY` missing/empty | STOP; message names the exact env var; write nothing (AC-1). |
| `postiz auth:status` reports not authenticated | STOP; message says credentials invalid/expired/absent; write nothing. |
| `postiz auth:status` errors / backend unreachable | STOP; message says the resolved Postiz backend URL is unreachable; write nothing. |
| `product-marketing` skill did not produce `.agents/product-marketing.md` | STOP at Step 5 verification; message says the marketing-context doc is missing; init's own config writes are discarded (atomic). |
| No `git remote origin` | `repo` becomes an interview gap; prompt for it. |
| No landing URL found | Field left blank (not required); no prompt needed unless founder wants one. |
| Existing config + "Keep existing" | Print summary, STOP, no writes. |
| Existing config + "Merge" / "Re-run" | Re-enter at Steps 1–2 (dependency check + Postiz gate re-run); then backfill or rewrite per Re-run Safety; never clobber set values silently. |
| Any Step failing after Step 2 passes | STOP with actionable message; **atomic write** guarantees init's config paths are left untouched — delete the staging area, leave no partially-written config set. |

## Permissions & Trust Posture

No RBAC model exists in this repo — the only actor is the founder running `/gtm:init` locally. There is no multi-role permission table to fill. Channel automation posture (draft/auto/manual, human-approval gates) is a downstream-story concern and out of scope here.

## Out of Scope

- Channel ownership / voice / cadence configuration (downstream story — NA-3 blocks it).
- KPI metric and source setup, provider catalogue, and the KPI verification probe (downstream story — the Epic's "Init orchestrates KPI setup" is realized by a separate story that this one unblocks).
- Engagement-listening provider config.
- Pulse loop, launch campaign, demo pipeline, digests content.
- The append-only JSONL content log and its dedupe/merge rules.
- **GTM-brief-producing workflows** — NA-3 ships the `product-marketing-manager` agent definition, but the workflows that invoke it to emit `docs/gtm/briefs/<date>-<slug>.md` belong to downstream stories (NA-4..NA-8, NA-11).
- Any change under `brand/` (read-only detection source only).
- Postiz **channel connection / posting / analytics** — init only verifies the skill is installed and the backend is reachable/authenticated via `postiz auth:status`; connecting channels, creating posts, uploading media, and reading analytics via the `postiz` skill are downstream-story work.

## Open Questions

None outstanding — all decisions are locked below.

## Decided (defaults locked by this spec)

- **Init owns setup — Decided:** `/gtm:init` performs detection, the product-marketing interview, and all config writes **in-command** (mirrors sdlc's `/init`); it does not dispatch an agent for setup. The Step-4 interview invokes the marketingskills `product-marketing` **skill**, which owns `.agents/product-marketing.md`.
- **Dependencies — Decided:** **two** plugin dependencies — `postiz@postiz-agent` and `marketing-skills@marketingskills`. `.claude-plugin/marketplace.json` `allowCrossMarketplaceDependenciesOn` = `["claude-plugins-official", "postiz-agent", "marketingskills"]` (the `claude-plugins-official` entry is pre-existing for **sdlc's** superpowers dep; gtm adds the other two).
- **`superpowers` dependency omitted — Decided:** deliberately **not** a gtm dependency — no gtm command or agent invokes a superpowers skill (the earlier inclusion copied sdlc's manifest shape without the usage). Add it back only when a future story actually uses a superpowers skill.
- **`marketingskills` adopted in NA-3 — Decided:** no longer deferred. Its `product-marketing` skill owns `.agents/product-marketing.md`; that repo-root path is the skill's expected location (the reason AC-3 places it there). No gtm `agent-binding-template.md` is authored.
- **PMM agent — Decided:** the agent is named `product-marketing-manager` (`plugins/gtm/agents/product-marketing-manager.md`), the marketing mirror of sdlc's `product-manager`. It outputs a **GTM brief** (positioning, messaging, target audience, channel rationale, launch angle) to `docs/gtm/briefs/<date>-<slug>.md` using the marketingskills skills + the `postiz` skill (never raw HTTP). NA-3 ships the definition only; brief workflows are downstream.
- **`deepline-gtm` skill — Decided (rejected):** the `deepline-gtm` skill (skills.sh / code.deepline.com) was evaluated for the GTM-brief role and **rejected** — it is sales-outbound prospecting/enrichment behind a paid vendor API requiring an account, not marketing-brief authoring; and its install instructions rely on sandbox-bypass npm-prefix + custom-registry patterns that fail our supply-chain bar.
- **Postiz operations — Decided:** all Postiz interaction (init's gate and every downstream action) goes through the `postiz` skill from `postiz@postiz-agent`; gtm never hand-rolls HTTP against Postiz.
- **Postiz reachability gate — Decided:** `postiz auth:status` via the CLI; the CLI owns endpoint/transport/auth details (this resolves the former "Postiz probe endpoint" open question — no hand-rolled HTTP probe).
- **Postiz env-var contract — Decided:** `POSTIZ_API_URL` (backend URL) + `POSTIZ_API_KEY` (API key) — both required by the CLI at run time; the init gate uses the API-key env var (OAuth is not an accepted gate path). The backend URL is a **persisted config token** in `marketing-context.md` (chosen at init via `AskUserQuestion`: cloud default `https://api.postiz.com` or self-hosted — not a secret), which commands export as `POSTIZ_API_URL` before invoking the CLI; an already-set `POSTIZ_API_URL` env var only **seeds** the init-time choice, never persists silently. `marketing-context.md` persists only the API key's env-var **name**, never its value.
- **`marketing-context.md` location — Decided:** `.claude/project/marketing-context.md` (mirrors `project-context.md`; auto-loaded by the SessionStart hook). It is gtm's plugin config, distinct from `.agents/product-marketing.md` (owned by the marketingskills skill).
- **`.agents/product-marketing.md` path — Decided:** repo-root `.agents/product-marketing.md`, per AC-3 — the file the marketingskills `product-marketing` skill creates and maintains.
- **Vendored script set — Decided:** gtm has **no** sdlc dependency; vendor the complete set — `session-complete.sh`, `cleanup-tmp.sh`, `tmp-dir.sh`, and the shared sibling `session-key.sh` — into `plugins/gtm/scripts/`, and resolve every call via `${CLAUDE_PLUGIN_ROOT}/scripts/…`.
- **Plugin version — Decided:** `plugins/gtm/.claude-plugin/plugin.json` starts at `0.1.0` (independent of sdlc's version line).
