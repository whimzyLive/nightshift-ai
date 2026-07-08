# Configure per-channel ownership via /gtm:init picker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [docs/superpowers/specs/NA-4.md](../specs/NA-4.md)
**Date:** 2026-07-09
**Story:** [NA-4](https://whimzylive.atlassian.net/browse/NA-4) — Configure per-channel ownership via /gtm:init picker
**Epic:** [NA-2](https://whimzylive.atlassian.net/browse/NA-2) — GTM marketing plugin for nightshift marketplace
**Agents required:** `ai-enablement-engineer` (only active agent in scope — owns `plugins/` and `skills/`)

**Goal:** Add a per-channel configuration step to `/gtm:init` that enumerates connected Postiz channels and captures ownership/voice/cadence/content-types per channel, persisted as a `## Channels` table in `.claude/project/marketing-context.md`.

**Architecture:** Three coordinated Markdown edits inside `plugins/gtm/`. A new protocol ref (`channel-config.md`) defines the picker's enumeration, prompt set, locked enums/defaults, empty-list handling, and re-run matching. The `marketing-context-template.md` gains the `## Channels` section + schema rows + fill rules. `commands/init.md` inserts Step 4b (applying the ref) and extends Steps 0/5/6. NA-4 persists config only — no publish/draft/manual behaviour (downstream pulse story).

**Tech Stack:** Markdown + Shell AI-plugin workspace. No database, backend, web, mobile, or offline-sync layer. Postiz channel discovery delegates to the `postiz` CLI (`postiz integrations:list`) — gtm never hand-rolls HTTP.

## Execution order

Single domain — **all tasks tagged `[ai-enablement-engineer]`, marked DEPENDENCY-FREE** (no other domain agent's artifact is consumed or produced). Executed sequentially, one agent, on the shared `feat/NA-4` branch. Task order is dependency-driven: the protocol ref (Task 1) is authored first so it can be cited by the command; the template (Task 2) defines the schema the command renders; the command edit (Task 3) consumes both; Task 4 verifies cross-file consistency.

## Global Constraints

Values copied verbatim from the spec — every task's requirements implicitly include these:

- **Ownership enum:** `auto` | `draft` | `manual`. Default `draft` (AC-4). `reddit` identifier pre-selected to `manual` as a *recommended* default (overridable; un-touched channel still falls back to `draft`).
- **Voice enum:** `brand` | `founder`. Default `brand`. Distinct from the global `## Voice` overrides section (which stays empty at init).
- **Cadence enum:** `default` | `daily` | `weekly` | `paused`. Default `default`.
- **Content-type catalogue (locked, six values):** `release-note` · `tip` · `thread` · `article-link` · `demo-clip` · `milestone`. Content-types default `release-note, milestone` (multi-select subset).
- **Channels table columns (exact order):** `Channel` | `Name` | `Integration ID` | `Ownership` | `Voice` | `Cadence` | `Content types`.
- **Column sources:** `Channel` = Postiz `identifier`; `Name` = Postiz `name`; `Integration ID` = Postiz `id` (refreshed every run).
- **Enumeration:** `postiz integrations:list` (JSON array; each element exposes `id`, `name`, `identifier`). `POSTIZ_API_URL` must be exported (already done by init Step 2) before the call. Never hand-roll HTTP.
- **Re-run match key:** `Integration ID` first, fall back to (`Channel` identifier, `Name`) pair.
- **AC-4:** any channel with no explicit ownership defaults to `draft`. **AC-5:** re-running preserves existing per-channel settings unless the founder explicitly changes them; no setting is ever silently overwritten or dropped.
- **Empty enumeration:** fresh run (or re-entry with no prior rows) → write empty table (header + separator only) + "connect channels in Postiz and re-run" note; **not** a hard stop. Re-entry **with** prior rows → drop-confirmation guard, never a silent wipe.
- **Enumeration transport error** (non-zero exit after Step 2 auth passed) → STOP, write nothing (atomic staging untouched).
- **Malformed entry** (missing `id`/`name`/`identifier`) → skip + warn, continue with the rest.
- Out of scope: publish behaviour, KPI setup, channel-graduation automation, Hacker News / Product Hunt (not Postiz integrations), global `## Voice` overrides, connecting new channels, any change under `tools/` or `brand/`.

---

### Task 1: New protocol ref — `plugins/gtm/refs/channel-config.md`

**Files:**
- Create: `plugins/gtm/refs/channel-config.md`
- Reference (structural pattern, do not modify): `plugins/gtm/refs/postiz-verify.md`, `plugins/gtm/refs/product-detect.md`

**Interfaces:**
- Consumes: nothing (dependency-free; only cites the `postiz` CLI contract already used by `postiz-verify.md`).
- Produces: the `channel-config` picker protocol that `commands/init.md` Step 4b will apply by reference (`${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md`). Downstream Task 3 cites this file; the Channels table schema it describes must match Task 2 exactly.

- [ ] **Step 1: Author the ref**, mirroring the thin-command structure of `postiz-verify.md` (intro line stating it is applied by `/gtm:init` Step 4b and delegates all Postiz access to the `postiz` CLI with `POSTIZ_API_URL` exported). Include these sections, each concrete:
  - **Enumeration** — run `postiz integrations:list` (AC-1); parse `id`, `name`, `identifier` per element. State that `identifier` = platform key (e.g. `x`, `linkedin`, `reddit`, `bluesky`, `mastodon`), `name` = human account display name (disambiguates two accounts on one platform), `id` = the downstream `postiz posts:create -i <id>` publish handle (can change on reconnect). Note Hacker News / Product Hunt are not Postiz integrations and never appear here.
  - **Per-channel prompt set** — for each channel, one at a time, prompt for the four settings, each pre-seeded with the existing value (re-run) or schema default (fresh):
    - Ownership — single-select `auto`/`draft`/`manual`, default `draft` (AC-4); `reddit` identifier pre-selected `manual` (recommended, overridable); skipped channel → `draft` fallback.
    - Voice — single-select `brand`/`founder`, default `brand`.
    - Cadence — single-select `default`/`daily`/`weekly`/`paused`, default `default` (`default` = inherit global pulse cadence ~3 posts/week, weekends quiet; `paused` = prepared but never scheduled).
    - Content types — multi-select from the six-value catalogue (`release-note`, `tip`, `thread`, `article-link`, `demo-clip`, `milestone`), default `release-note, milestone`.
    - State the step gathers values into an in-memory model only — writes nothing to final paths (Step 5 renders).
  - **Locked enums + defaults table** — reproduce the four enum lists and their defaults verbatim (must be identical to the Global Constraints above and to Task 2's schema rows).
  - **Empty-list handling** — empty `integrations:list` on a fresh run (or re-entry with no prior rows) → empty table (header + separator only) + one-line "channels can be connected in Postiz and picked up on the next `/gtm:init` run" note; continue. Empty on a re-entry with prior configured rows → drop-confirmation guard (see Re-run matching), never an automatic empty-table write.
  - **Re-run matching (AC-5)** — match existing rows to freshly enumerated channels by `Integration ID` first, else by (`Channel` identifier, `Name`) pair. Matched row: preserve `Ownership`/`Voice`/`Cadence`/`Content types` as-is (offer as pre-selected defaults if re-prompting), refresh only `Integration ID`. Newly discovered channel → schema defaults (`Ownership = draft`). A previously configured channel no longer returned → list affected channels + require explicit founder confirmation before dropping; on decline, STOP with existing rows intact (nothing written). Two accounts sharing a platform `identifier` → disambiguate by `Name`.
  - **Error handling** — transport/non-zero exit after Step 2 auth passed → STOP with the actionable message: "could not enumerate Postiz channels via `postiz integrations:list`; confirm the backend is reachable and re-run `/gtm:init`"; write nothing. Malformed entry (missing `id`/`name`/`identifier`) → skip + warn which channel, continue.

- [ ] **Step 2: Self-check the ref** — every enum value, default, and column name matches the Global Constraints block verbatim; no `<placeholder>` token remains except the intentional `<id>` illustration inside example table rows; the file cites the `postiz` CLI (never raw HTTP).

---

### Task 2: Extend the template — `plugins/gtm/refs/marketing-context-template.md`

**Files:**
- Modify: `plugins/gtm/refs/marketing-context-template.md` (add `## Channels` to the fenced template block; add schema rows; add fill rules)

**Interfaces:**
- Consumes: the locked enums/defaults from Task 1 (must stay identical).
- Produces: the `## Channels` markdown table + schema + fill rules that `commands/init.md` Step 5 renders into the staged `project/marketing-context.md`. Task 3 Step 5 edit renders exactly this table shape.

- [ ] **Step 1: Add the `## Channels` section to the fenced template block**, placed after the `## Postiz` section and before the `## Voice` section (so per-channel Voice sits distinct from, and above, the global Voice overrides). Use this exact table shape (illustrative rows show the format; the written file materialises real rows):

```markdown
## Channels

| Channel  | Name              | Integration ID | Ownership | Voice   | Cadence | Content types              |
| -------- | ----------------- | -------------- | --------- | ------- | ------- | -------------------------- |
| x        | Nightshift        | <id>           | draft     | brand   | default | release-note, milestone    |
| linkedin | Rishi Patel       | <id>           | draft     | founder | weekly  | release-note, article-link |
| reddit   | u/nightshift-bot  | <id>           | manual    | founder | paused  | article-link               |
```

- [ ] **Step 2: Add channel column rows to the `## Schema` table** — one row per column, matching the spec's column schema exactly:
  - `Channels` / `Channel` / string — Postiz `identifier` / Yes / — / Platform key from `integrations:list`.
  - `Channels` / `Name` / string — Postiz `name` / Yes / — / Account display name; disambiguates multiple accounts on one platform.
  - `Channels` / `Integration ID` / string — Postiz `id` / Yes / — / Refreshed every run; downstream publish handle; primary re-run match key but not stable identity (reconnect can go stale — `(Channel, Name)` fallback applies).
  - `Channels` / `Ownership` / enum `auto`\|`draft`\|`manual` / Yes / `draft` / AC-4: any channel not explicitly set is `draft`.
  - `Channels` / `Voice` / enum `brand`\|`founder` / Yes / `brand` / `brand` = product/brand account voice; `founder` = founder's personal voice; distinct from the global Voice overrides section.
  - `Channels` / `Cadence` / enum `default`\|`daily`\|`weekly`\|`paused` / Yes / `default` / `default` = inherit global pulse cadence; `paused` = prepared but never scheduled.
  - `Channels` / `Content types` / comma-separated subset of the six-value catalogue / Yes / `release-note, milestone` / Multi-select.

- [ ] **Step 3: Add a Content-type catalogue note** near the schema (the six locked values with their one-line meanings): `release-note` (shipped feature / merged PR / changelog highlight), `tip` (usage tip / how-to), `thread` (long-form multi-part narrative), `article-link` (link to a cross-posted long-form article), `demo-clip` (the VHS + Remotion demo video), `milestone` (KPI / community milestone, e.g. star count).

- [ ] **Step 4: Add channel Fill rules** to the `## Fill rules` list:
  - Materialise every channel row fully — no `<...>` placeholder token may remain (`Integration ID` filled from the live `integrations:list` `id`).
  - When `integrations:list` returns zero channels, write the empty-table form (header + separator rows only) plus the one-line "connect channels in Postiz and re-run" note.
  - Per-channel `Voice` column ≠ the global `## Voice` overrides section — the latter stays empty at init.
  - On the Merge/Re-run path, preserve every existing channel setting; only backfill channels/settings absent from the file; refresh `Integration ID` every run (per Task 1 re-run matching).

- [ ] **Step 5: Self-check** — the `## Channels` template block, the seven schema rows, and the catalogue match Task 1's enums/defaults verbatim; column order is `Channel | Name | Integration ID | Ownership | Voice | Cadence | Content types` in both the template and the schema; only intentional `<id>` illustration placeholders remain inside the example template rows.

---

### Task 3: Wire the picker into `/gtm:init` — `plugins/gtm/commands/init.md`

**Files:**
- Modify: `plugins/gtm/commands/init.md` (insert Step 4b; extend Steps 0, 5, 6; extend the front-matter `description` if needed)

**Interfaces:**
- Consumes: the `channel-config.md` protocol from Task 1 (applied by reference in Step 4b) and the extended `marketing-context-template.md` from Task 2 (rendered in Step 5).
- Produces: the founder-facing `/gtm:init` behaviour. No downstream task consumes this in NA-4.

- [ ] **Step 1: Insert Step 4b — Channel configuration**, slotted after Step 4 (product-marketing interview) and before Step 5 (atomic write). Body applies `${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md`:
  - State preconditions already met: Step 2 confirmed Postiz auth and exported `POSTIZ_API_URL`; on a fresh run the existing table is empty; on a Merge/Re-run re-entry Step 0 has already captured the current Channels rows.
  - Enumerate via `postiz integrations:list` (AC-1); parse `id`/`name`/`identifier`.
  - For each channel, prompt one at a time for the four settings (Ownership/Voice/Cadence/Content types), pre-seeded with existing value (re-run) or schema default (fresh) per the ref. Note the `reddit` recommended-`manual` default and the AC-4 `draft` fallback for skipped channels.
  - Collect answers into the in-memory Channels model Step 5 renders; this step writes nothing to final paths.
  - Reference the ref's error handling (transport error → STOP write-nothing; empty-list handling; malformed-entry skip; drop-confirmation guard) rather than re-specifying it inline.

- [ ] **Step 2: Extend Step 0 (Re-init guard)** so both Merge and Re-run capture the current `marketing-context.md` Channels rows before re-entering:
  - **Merge new findings** → run Step 4b, preserve every existing setting per enumerated channel, backfill only channels/settings absent from the file (new channels → defaults, AC-4); re-prompt only for genuinely new channels.
  - **Re-run full setup** → run Step 4b for every channel with existing values offered as defaults; the founder may change any.
  - **Keep existing** → unchanged (STOP, no writes); add a one-line channel count to the current-config summary Step 0 prints (e.g. "Channels configured: 4").

- [ ] **Step 3: Extend Step 5 (Write)** — render the collected Channels model into the staged `project/marketing-context.md` using the extended template (Task 2). No placeholder token (`<...>`) may remain — every channel row fully materialised, or the empty-table form written when no channels exist. Keep the NA-3 atomic staged-write + move guarantee unchanged (Channels table is part of the last-moved `marketing-context.md`).

- [ ] **Step 4: Extend Step 6 (Post-init checklist)** — add the summary line verbatim: "**Channels configured:** N (ownership/voice/cadence/content-types per channel) — graduate a channel from `draft` to `auto` by re-running `/gtm:init` and changing its ownership." Note any channel dropped on a re-run (per the drop-confirmation guard) in this summary.

- [ ] **Step 5: Update the front-matter `description`** (one clause) to mention per-channel Postiz channel configuration, keeping it a single-line description consistent with the existing style.

- [ ] **Step 6: Self-check** — Step 4b sits between Step 4 and Step 5; every reference resolves (`${CLAUDE_PLUGIN_ROOT}/refs/channel-config.md`); enums cited in the command match Tasks 1–2 verbatim; the Step 6 summary line is present and exact.

---

### Task 4: Cross-file consistency verification

**Files:**
- Verify (read-only): `plugins/gtm/refs/channel-config.md`, `plugins/gtm/refs/marketing-context-template.md`, `plugins/gtm/commands/init.md`

**Interfaces:**
- Consumes: all three edited files (Tasks 1–3).
- Produces: pass/fail signal — this repo has no typecheck/lint gate (Markdown + Shell), so verification is a Markdown cross-reference + enum-consistency check.

- [ ] **Step 1: No stray placeholder tokens** — confirm no unintended `<...>` token remains in the three files (the only permitted `<...>` are the illustrative `<id>` cells inside example template rows).

Run:
```bash
grep -nE '<[^>]+>' plugins/gtm/refs/channel-config.md plugins/gtm/refs/marketing-context-template.md plugins/gtm/commands/init.md | grep -v '<id>'
```
Expected: no output other than known intentional tokens (`${CLAUDE_PLUGIN_ROOT}` is `${...}`, not `<...>`, and is fine). Investigate any `<...>` hit that is not an example `<id>` cell.

- [ ] **Step 2: Cross-references resolve** — confirm `commands/init.md` cites `refs/channel-config.md` and `refs/marketing-context-template.md`, and both ref files exist.

Run:
```bash
grep -n 'channel-config.md' plugins/gtm/commands/init.md
grep -n 'marketing-context-template.md' plugins/gtm/commands/init.md
test -f plugins/gtm/refs/channel-config.md && test -f plugins/gtm/refs/marketing-context-template.md && echo "REFS_EXIST=yes"
```
Expected: at least one citation of each ref in `init.md`, and `REFS_EXIST=yes`.

- [ ] **Step 3: Enum consistency across the three files** — confirm the ownership/voice/cadence enums and the content-type catalogue appear identically wherever stated.

Run:
```bash
grep -rn 'auto.*draft.*manual' plugins/gtm/refs/channel-config.md plugins/gtm/refs/marketing-context-template.md plugins/gtm/commands/init.md
grep -rn 'default.*daily.*weekly.*paused' plugins/gtm/refs/channel-config.md plugins/gtm/refs/marketing-context-template.md
grep -rn 'release-note' plugins/gtm/refs/channel-config.md plugins/gtm/refs/marketing-context-template.md
```
Expected: ownership enum (`auto`/`draft`/`manual`), cadence enum (`default`/`daily`/`weekly`/`paused`), and the content-type catalogue read identically across the files — no drift (e.g. a value spelled differently or a fifth cadence value). Manually reconcile any mismatch.

- [ ] **Step 4: Column-order consistency** — confirm the Channels table header column order (`Channel | Name | Integration ID | Ownership | Voice | Cadence | Content types`) is identical in the ref's example table and the template's `## Channels` block.

Run:
```bash
grep -n 'Integration ID.*Ownership.*Voice.*Cadence.*Content types' plugins/gtm/refs/channel-config.md plugins/gtm/refs/marketing-context-template.md
```
Expected: matching header rows in both files. Reconcile any column-order difference.

---

## Self-review

- **Spec coverage:** AC-1 (enumerate via `integrations:list`) → Task 1 Enumeration + Task 3 Step 1. AC-2 (per-channel ownership/voice/cadence/content-types) → Task 1 prompt set + Task 3 Step 1. AC-3 (written into Channels table) → Task 2 + Task 3 Step 3. AC-4 (default `draft`) → Global Constraints + Tasks 1/2/3. AC-5 (re-run preserves) → Task 1 Re-run matching + Task 3 Step 2. Error-handling matrix → Task 1 Error handling + Task 3 Step 1. Step 0/5/6 extensions → Task 3 Steps 2–4. All spec deliverables (three files) mapped to Tasks 1–3; Task 4 is the verification gate.
- **Phase order:** single domain (`ai-enablement-engineer`, DEPENDENCY-FREE) — no DB/backend/sync/web/mobile phases apply (Markdown + Shell repo).
- **No TBDs:** every enum, default, column name, and section placement is concrete and copied from the spec.
- **Consistency:** enums and column order stated identically in Global Constraints and each task; Task 4 mechanically re-checks them.

## Complexity

**Low** — one domain agent, three Markdown files, one verification task. No cross-agent handoff.
