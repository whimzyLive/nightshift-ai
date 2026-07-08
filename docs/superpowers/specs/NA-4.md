# Configure per-channel ownership via /gtm:init picker — Technical Spec

**Story:** [NA-4](https://whimzylive.atlassian.net/browse/NA-4)
**Epic:** [NA-2 — GTM marketing plugin for nightshift marketplace](https://whimzylive.atlassian.net/browse/NA-2)
**Date:** 2026-07-08

## Overview

Add a channel-configuration step to `/gtm:init` that enumerates the founder's connected Postiz channels and, per channel, captures ownership (auto/draft/manual), voice (brand/founder), cadence, and content types. The selections are persisted as a **Channels** table in `.claude/project/marketing-context.md`, giving the downstream pulse/launch engine the trust posture it must respect per channel.

## Acceptance Criteria

- **AC-1** — Init lists all available Postiz channels via `postiz integrations:list`.
- **AC-2** — For each channel the founder can set ownership (`auto`/`draft`/`manual`), voice (`brand`/`founder`), cadence, and content types.
- **AC-3** — Selections are written into the `marketing-context.md` **Channels** table.
- **AC-4** — A channel with no explicit ownership set defaults to `draft`.
- **AC-5** — Re-running the picker preserves existing per-channel settings unless the founder explicitly changes them.

## Context & Scope Boundary

`gtm` is nightshift's second plugin (`plugins/gtm/`, beside `plugins/sdlc/`). NA-4 **builds on** NA-3 (the `/gtm:init` bootstrap foundation) and is **blocked by** it; NA-4 in turn **blocks** NA-8 (launch) and NA-10. NA-4 delivers only the **per-channel configuration surface** inside init and the config schema it writes — it does **not** publish, schedule, or enforce any ownership behaviour (that is the pulse story's job).

**This is a Markdown + Shell plugin repo.** There is no database, HTTP API, web UI, mobile app, or offline-sync layer in scope — those writing-specs template sections are omitted deliberately. The "data model" here is a **config-file schema** (the `marketing-context.md` Channels table), specified under Config Schema below.

### Postiz channel enumeration — the `postiz@postiz-agent` skill

Channel discovery goes through the already-adopted `postiz` skill/CLI (installed as a gtm dependency in NA-3). Verified command contract (postiz CLI 2.0.x):

- `postiz integrations:list` returns a JSON array of connected channels; each element exposes at least `id`, `name`, and `identifier` (e.g. `x`, `linkedin`, `reddit`, `bluesky`, `mastodon`).
  - `identifier` = the platform key (stable across re-runs unless the account is reconnected).
  - `name` = the human account/display name (disambiguates two accounts on the same platform).
  - `id` = the Postiz integration id — the handle downstream `postiz posts:create -i <id>` requires; it can change if a channel is disconnected and re-linked.
- gtm **never hand-rolls HTTP against Postiz** — it delegates to the CLI. `POSTIZ_API_URL` must be exported (already resolved and exported by init Step 2) before the call.

Hacker News and Product Hunt are **not** Postiz integrations, so they never appear in `integrations:list` and are out of scope for this picker (they are queue-only, human-driven channels handled elsewhere).

### Ownership semantics (config only — behaviour is downstream)

| Ownership | Meaning the downstream engine will honour |
| --------- | ----------------------------------------- |
| `auto`    | Engine may publish to this channel unattended. |
| `draft`   | Engine prepares content; a human reviews/approves before it publishes. |
| `manual`  | Engine only prepares queue assets; the founder posts by hand. |

NA-4 records these values; it does **not** implement the publish/draft/manual behaviour. Channel graduation (`draft → auto`) is always a founder config change — the engine never auto-promotes (Epic "Channel graduation" resolved decision); that recommendation logic lives in the pulse/report story, not here.

## Config Schema — `marketing-context.md` Channels table

NA-4 adds one new section to the `marketing-context.md` template and its schema. This is the sole persisted artifact of the story.

### New section (rendered into `.claude/project/marketing-context.md`)

```markdown
## Channels

| Channel  | Name              | Integration ID | Ownership | Voice   | Cadence | Content types            |
| -------- | ----------------- | -------------- | --------- | ------- | ------- | ------------------------ |
| x        | Nightshift        | <id>           | draft     | brand   | default | release-note, milestone  |
| linkedin | Rishi Patel       | <id>           | draft     | founder | weekly  | release-note, article-link |
| reddit   | u/nightshift-bot  | <id>           | manual    | founder | paused  | article-link             |
```

When `integrations:list` returns zero channels, the section is still written with an **empty table** (header + separator rows only) plus a one-line note that channels can be connected in Postiz and picked up on the next `/gtm:init` run. Exception: on a re-entry that already has configured rows, an empty enumeration triggers the drop-confirmation guard (see Re-run matching / Error Handling) rather than an automatic empty-table write.

### Column schema

| Column | Type / allowed values | Required | Default | Notes |
| ------ | --------------------- | -------- | ------- | ----- |
| `Channel` | string — Postiz `identifier` | Yes | — | Platform key from `integrations:list`. |
| `Name` | string — Postiz `name` | Yes | — | Account display name; disambiguates multiple accounts on one platform. |
| `Integration ID` | string — Postiz `id` | Yes | — | Refreshed from `integrations:list` on **every** run; downstream publish handle. Primary match key on re-run, but not a stable identity key — it can go stale on reconnect, in which case the (`Channel`, `Name`) fallback applies (see Re-run matching). |
| `Ownership` | enum: `auto` \| `draft` \| `manual` | Yes | `draft` | AC-4: any channel not explicitly set is `draft`. |
| `Voice` | enum: `brand` \| `founder` | Yes | `brand` | `brand` = product/brand account voice; `founder` = founder's personal voice. Distinct from the global **Voice** overrides section (which stays empty at init). |
| `Cadence` | enum: `default` \| `daily` \| `weekly` \| `paused` | Yes | `default` | `default` = inherit the global pulse cadence (~3 posts/week, weekends quiet); `paused` = prepared but never scheduled. |
| `Content types` | comma-separated subset of the content-type catalogue (below) | Yes | `release-note, milestone` | Multi-select. |

### Content-type catalogue (locked by this spec)

`release-note` (shipped feature / merged PR / changelog highlight) · `tip` (usage tip / how-to) · `thread` (long-form multi-part narrative) · `article-link` (link to a cross-posted long-form article) · `demo-clip` (the VHS + Remotion demo video) · `milestone` (KPI / community milestone, e.g. star count).

### Re-run matching (AC-5)

On a Merge or Re-run re-entry, existing Channels rows are matched to freshly enumerated channels by **`Integration ID` first**, falling back to the **(`Channel` identifier, `Name`)** pair when no `Integration ID` match is found in the freshly enumerated list (e.g. a reconnected channel — its stored id is present but stale, so it matches nothing). A matched row's `Ownership` / `Voice` / `Cadence` / `Content types` are **preserved as-is** and offered as the pre-selected defaults if re-prompting; only the `Integration ID` is refreshed. A newly discovered channel with no matching row gets the schema defaults — `Ownership = draft` (AC-4). A previously configured channel that is no longer returned by `integrations:list` is **dropped** from the rewritten table (it is no longer connected) — but never silently: any re-run that would drop one or more previously configured rows must list the affected channels and get explicit founder confirmation before writing; if the founder declines, STOP with the existing rows intact (nothing written). In particular, an **empty** enumeration on a re-entry that has existing configured rows (API key pointed at a different Postiz org, backend reset — `auth:status` can still pass) must never auto-write an empty table over them. No setting is ever silently overwritten or dropped (AC-5).

## Command Surface — `/gtm:init` changes

The picker runs **inside `/gtm:init`** (AC references "the picker" as part of init). It is a new step slotted **after Step 4 (product-marketing interview)** and **before Step 5 (atomic write)** — the Channels table is part of the `marketing-context.md` that Step 5 writes atomically, so its values must be collected first. Call it **Step 4b — Channel configuration**.

### Step 4b — Channel configuration (new)

Preconditions already met by earlier steps: Step 2 has confirmed Postiz auth and exported `POSTIZ_API_URL`; on a fresh run the existing table is empty, on a Merge/Re-run re-entry Step 0 has already captured the current Channels rows.

1. Enumerate: `postiz integrations:list` (AC-1). Parse `id`, `name`, `identifier` per channel.
2. For **each** channel, prompt the founder — one channel at a time — for the four settings (AC-2), each pre-seeded with the existing value (re-run) or the schema default (fresh):
   - **Ownership** — single-select `auto` / `draft` / `manual`. Default `draft` (AC-4). The `reddit` identifier is pre-selected to `manual` as a **recommended** default (Epic: subreddit norms punish brand-account automation) — the founder may override; if the founder skips the channel entirely, the AC-4 fallback `draft` applies.
   - **Voice** — single-select `brand` / `founder`. Default `brand`.
   - **Cadence** — single-select `default` / `daily` / `weekly` / `paused`. Default `default`.
   - **Content types** — multi-select from the catalogue. Default `release-note, milestone`.
3. Collect the answers into the in-memory Channels model that Step 5 renders. This step **writes nothing** to final paths — it only gathers values.

The exact prompt grouping/wording is left to the implementer (see Implementation Guide) provided every setting resolves to a concrete enum value with no placeholder left unset.

### Step 0 — Re-init guard (extend)

Extend the existing re-init handling so that both **Merge** and **Re-run** capture the current `marketing-context.md` Channels rows before re-entering:

- **Merge new findings** → run Step 4b, but for each enumerated channel preserve every existing setting and only backfill channels/settings absent from the file (new channels → defaults, AC-4). Re-prompt only for genuinely new channels.
- **Re-run full setup** → run Step 4b for every channel with existing values offered as defaults; the founder may change any.
- **Keep existing** → unchanged; STOP, no writes; the current-config summary printed by Step 0 gains a one-line channel count (e.g. "Channels configured: 4").

### Step 5 — Write (extend)

Render the collected Channels model into the staged `project/marketing-context.md` using the extended template (below). No placeholder token (`<...>`) may remain — every channel row is fully materialised, or the empty-table form is written when no channels exist. The atomic staged-write + move guarantee from NA-3 is unchanged; the Channels table is part of the last-moved `marketing-context.md`.

### Step 6 — Post-init checklist (extend)

Add a line to the summary: "**Channels configured:** N (ownership/voice/cadence/content-types per channel) — graduate a channel from `draft` to `auto` by re-running `/gtm:init` and changing its ownership."

## Deliverables

Owner: **ai-enablement-engineer** (owns `plugins/` and `skills/` per `.claude/project/project-context.md`). This is the only active agent required — no `tools/` (platform-engineer) or `brand/` (web-engineer) change is in scope.

| # | File | Change |
| - | ---- | ------ |
| 1 | `plugins/gtm/refs/channel-config.md` | **New ref** — the channel-picker protocol: enumerate via `postiz integrations:list`, the per-channel prompt set, the locked enums + defaults, the empty-list handling, and the re-run matching rules. Mirrors the thin-command pattern of `postiz-verify.md` / `product-detect.md`. |
| 2 | `plugins/gtm/refs/marketing-context-template.md` | Add the `## Channels` section to the template, add its column rows to the **Schema** table, and add the channel Fill rules (materialise every row; empty-table form when no channels; per-channel voice ≠ global Voice section). |
| 3 | `plugins/gtm/commands/init.md` | Insert **Step 4b — Channel configuration** (applying ref #1); extend Step 0 (Merge/Re-run capture + Keep-existing summary line), Step 5 (render the Channels table), and Step 6 (channels summary line). |

Use the existing `plugins/gtm/refs/postiz-verify.md` and `plugins/gtm/commands/init.md` as structural references. Keep all in-command Postiz calls delegated to the `postiz` CLI with `POSTIZ_API_URL` exported.

## Error Handling

| Scenario | Behaviour |
| -------- | --------- |
| `postiz integrations:list` returns an **empty** array (fresh run, or re-entry with no previously configured rows) | Not an error. Write the empty Channels table + the "connect channels in Postiz and re-run" note; continue to Step 5. |
| `postiz integrations:list` returns an **empty** array on a Merge/Re-run re-entry with previously configured rows | Guard against a silent wipe (AC-5): list the rows that would be dropped and require explicit founder confirmation before writing the empty table; on decline, STOP with the existing rows intact (nothing written). |
| `postiz integrations:list` **errors** (transport / non-zero exit) after Step 2 auth passed | STOP with an actionable message ("could not enumerate Postiz channels via `postiz integrations:list`; confirm the backend is reachable and re-run `/gtm:init`"); write nothing — the atomic staging guarantee leaves config untouched. |
| An enumerated channel is missing `id`, `name`, or `identifier` | Skip that malformed entry, warn which channel was skipped, continue with the rest. |
| Founder skips / declines to set a channel's ownership | Apply AC-4 default `draft` (never left blank). |
| Re-run: an existing configured channel no longer returned by `integrations:list` | Confirm the drop with the founder (see Re-run matching — never silent), then drop it from the rewritten table and note the drop in the Step 6 summary; on decline, STOP with nothing written. |
| Re-run: two accounts share a platform `identifier` | Disambiguate rows by `Name`; match/preserve per (identifier, Name). |

## Permissions & Trust Posture

No RBAC model exists in this repo — the only actor is the founder running `/gtm:init` locally. There is no multi-role permission table to fill. The **per-channel ownership** value NA-4 records **is** the trust posture, but NA-4 only persists it — enforcement (auto-publish vs human-gated draft vs manual) is downstream (pulse story).

## Out of Scope

- **Actual publishing behaviour per ownership state** — auto-publish, the draft-approval gate, and manual queue-asset preparation are the pulse story's job (Epic, explicit in the story's Out of Scope).
- **KPI / engagement source setup** — separate story (NA-5 / NA-6).
- **Channel graduation automation** — `draft → auto` is always a founder config change; the ~10-untouched-drafts promotion *recommendation* belongs to the pulse/report story, not this picker.
- **Hacker News / Product Hunt** — not Postiz integrations; never enumerated here; human-driven queue-only channels handled elsewhere.
- **Global Voice overrides** — the `## Voice` section of `marketing-context.md` (ECC anti-slop overrides) stays empty at init and is owned by a different downstream story; NA-4's per-channel `Voice` column is a distinct concept.
- **Connecting / authenticating new Postiz channels** — the founder connects channels in Postiz itself; the picker only reads what `integrations:list` already returns.
- Any change under `tools/` or `brand/`.

## Open Questions (all resolved — defaults adopted)

- [x] Reddit default ownership vs AC-4. — **Resolved (adopted above):** the picker pre-selects `manual` for the `reddit` identifier as a *recommended* answer (Epic's subreddit-automation caution), while the universal AC-4 fallback for any un-touched channel remains `draft`. Both rules hold: a founder who runs the picker sees `manual` pre-selected for Reddit and can override; a founder who never touches a channel gets `draft`.
- [x] Content-type catalogue extensibility. — **Resolved (adopted above):** ship the six-value catalogue locked in Config Schema; per-repo extension of the catalogue is deferred to a downstream voice/content-strategy story.

## Decided (defaults locked by this spec)

- Picker lives **inside `/gtm:init`** as Step 4b (after the product-marketing interview, before the atomic write) — not a standalone command.
- Ownership enum `auto|draft|manual`; Voice enum `brand|founder`; Cadence enum `default|daily|weekly|paused`; content-type catalogue of six values — all fixed here.
- Persisted as a `## Channels` markdown table in `marketing-context.md`; `Integration ID` refreshed every run; re-run match key = `Integration ID` then (`Channel`, `Name`).
- Empty `integrations:list` → empty table + note, never a hard stop — except on a re-entry with previously configured rows, where the drop-confirmation guard applies (AC-5); a transport **error** → STOP with nothing written (atomic).
