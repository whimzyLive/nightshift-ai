# Set up KPI metric and source in init — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [docs/superpowers/specs/NA-5.md](../specs/NA-5.md)
**Date:** 2026-07-09
**Story:** [NA-5](https://whimzylive.atlassian.net/browse/NA-5) — Set up KPI metric and source in init
**Epic:** [NA-2](https://whimzylive.atlassian.net/browse/NA-2) — GTM marketing plugin for nightshift marketplace
**Agents required:** `ai-enablement-engineer` (only active agent in scope — owns `plugins/` and `skills/` per the project-context workspace→agent table)

**Goal:** Extend `/gtm:init` so the founder names the one growth metric that matters and selects its source (managed GitHub, custom command, or custom endpoint), with a live verification probe that reads one real numeric value before any config is written; the resolved KPI is persisted as a `## KPI` section in `.claude/project/marketing-context.md`.

**Architecture:** Three coordinated Markdown edits inside `plugins/gtm/`, mirroring the NA-4 shape. A new protocol ref (`kpi-config.md`) defines source selection, per-source auth/env walk-through, the per-source verification probe, numeric validation, and the STOP error table. `marketing-context-template.md` gains the `## KPI` section (nine fixed rows), its `## Schema` rows, and KPI fill rules. `commands/init.md` inserts **Step 4c** (applying the ref) and extends Steps 0/5/6. KPI is gathered into an in-memory model only; the sole config write is the atomic Step 5, so any probe STOP leaves every final path untouched.

**Tech Stack:** Markdown + Shell AI-plugin workspace. No database, backend, web, mobile, or offline-sync layer. The GitHub probe delegates to the `gh` CLI; custom probes run a founder-supplied shell command or `curl` against a founder-supplied endpoint. Postiz is **not** involved in KPI setup.

## Execution order

Single domain — **all tasks tagged `[ai-enablement-engineer]`, marked DEPENDENCY-FREE** (no other domain agent's artifact is consumed or produced; `plugins/**` is this agent's exclusive surface). Executed sequentially, one agent, on the shared `feat/NA-5` branch. Task order is dependency-driven: the protocol ref (Task 1) is authored first so it can be cited by the command; the template (Task 2) defines the schema the command renders; the command edit (Task 3) consumes both; Task 4 verifies cross-file consistency. This is a single-phase plan — no DB/backend/sync/web/mobile phases apply to a Markdown/Shell plugin change.

## Global Constraints

Values copied verbatim from the spec — every task's requirements implicitly include these:

- **No plugin-assumed metric name** — the founder always names `Metric name` free-text; it is never pre-filled and never defaulted (AC-1). Blank `Metric name` → re-prompt, never a written default.
- **v1 source catalogue (locked):** `managed:github` + `custom:command` + `custom:endpoint`. No other managed provider (further managed providers are deferred, demand-driven).
- **`Source type` enum:** `managed` | `custom` (AC-2). **`Provider` enum:** `github` (when `managed`) | `command` | `endpoint` (when `custom`).
- **`GitHub metric` enum (four countable repo fields):** `stars` | `forks` | `watchers` | `open-issues`. Suggested default `stars` (a source-mechanism default, not a metric-name default — AC-1 stays satisfied by `Metric name`). Blank for custom sources.
- **GitHub metric → jq field on `repos/<owner>/<name>`:** `stars` → `.stargazers_count`; `forks` → `.forks_count`; `watchers` → `.subscribers_count`; `open-issues` → `.open_issues_count`. **Caveat (Minor 5c):** `.open_issues_count` counts open issues **and open pull requests** — state this at metric selection so a founder who wants issues-only knows `open-issues` is an issues+PRs count.
- **KPI `## KPI` table — nine fixed rows, always all present, source-irrelevant cells blank:** `Metric name`, `Source type`, `Provider`, `GitHub metric`, `Custom command`, `Custom endpoint`, `Value path`, `Auth env var`, `Verified value`.
- **`gh` auth is checked ONLY when the GitHub source is selected** (AC-3). Custom sources never trigger a `gh` check.
- **The probe reads exactly ONE value and it must be numeric** — valid iff, after trimming surrounding whitespace, it matches `^-?[0-9]+(\.[0-9]+)?$`. Any failure STOPs Step 4c before the atomic write, writing nothing (AC-4).
- **Secret hygiene:** only env-var **names** (`Auth env var`) reach disk — never values. The GitHub source persists no secret (uses ambient `gh` auth). `Custom command` / `Custom endpoint` strings are persisted verbatim and must reference an env var, not embed a literal secret; the rendered section states this.
- **Auth injection convention (endpoint):** when `Auth env var` is set, the endpoint probe adds `-H "Authorization: Bearer $<name>"`, value read from the environment at run time. The stored `Custom endpoint` / `Custom command` string is itself shell-expanded at probe time, so an embedded `$VAR` (e.g. `?token=$VAR`) resolves from the environment. Any future reader (NA-9) MUST apply the same convention.
- **Step placement:** new **Step 4c**, after Step 4b (channel config), before the atomic Step 5. All 4x steps write only to in-memory models, so a probe STOP anywhere in 4c leaves the repo untouched — identical posture to the Step 2 Postiz gate.
- **Atomic write:** the KPI section lands as part of init's own Step-5 atomic write; `marketing-context.md` still moves **last** as the completion marker (unchanged from NA-3/NA-4).
- **Out of scope:** engagement-source config/polling (NA-11); KPI reporting/correlation/growth report (NA-9); additional managed providers; historical KPI time-series/scheduling; UTM correlation; any change under `tools/` (platform-engineer) or `brand/` (web-engineer), or to `plugin.json` / `load-marketing-context.sh` / scripts.

---

### Task 1: New protocol ref — `plugins/gtm/refs/kpi-config.md`

**Files:**
- Create: `plugins/gtm/refs/kpi-config.md`
- Reference (structural pattern, do not modify): `plugins/gtm/refs/channel-config.md`, `plugins/gtm/refs/postiz-verify.md`

**Interfaces:**
- Consumes: nothing (dependency-free; cites the `gh` CLI and `curl`/`jq` contracts, and reads the Product `Repo` token that Step 3 detection already resolves into `marketing-context.md`).
- Produces: the `kpi-config` protocol that `commands/init.md` Step 4c will apply by reference (`${CLAUDE_PLUGIN_ROOT}/refs/kpi-config.md`). Downstream Task 3 cites this file; the KPI table/schema it describes must match Task 2 exactly.

- [ ] **Step 1: Author the ref**, mirroring the thin-command structure of `channel-config.md` (intro line stating it is applied by `/gtm:init` Step 4c, that it only **gathers into an in-memory KPI model** and writes nothing to any final path — Step 5 renders it). Include these sections, each concrete:

  - **Source selection prompt** — state that `Metric name` is captured **first**, free-text, no default, required (AC-1); a blank answer re-prompts. Then an `AskUserQuestion`, single-select, three options:
    - **Managed: GitHub** — read a repo metric via the `gh` CLI (only managed provider at v1).
    - **Custom command** — run a shell command that prints the current value to stdout.
    - **Custom endpoint** — HTTP GET a URL that returns the current value.
    Record the resolved `Source type` (`managed`/`custom`) and `Provider` (`github`/`command`/`endpoint`).

  - **Per-source auth/env + probe — Managed: GitHub**
    1. Auth (AC-3): require `gh` installed **and** `gh auth status` authenticated. STOP with a **distinct** message on each failure (install `gh` / run `gh auth login`).
    2. Resolve `<owner>/<name>` from the Product `Repo` token (normalise to `owner/name`). If the token is a non-GitHub URL or otherwise unresolvable to `owner/name`, STOP.
    3. Prompt for `GitHub metric` (single-select `stars`/`forks`/`watchers`/`open-issues`, default `stars`). **State the `open-issues` caveat (Minor 5c):** `open-issues` maps to `.open_issues_count`, which includes open **pull requests** as well as issues. No env-var prompt for GitHub.
    4. Probe (AC-4): read one value via a single `gh api` call, mapped by `GitHub metric` using the jq-field table from Global Constraints. Example:
       ```bash
       gh api "repos/<owner>/<name>" --jq '.stargazers_count'
       ```
       Non-zero exit or non-numeric output → STOP.

  - **Per-source auth/env + probe — Custom: command**
    1. Env (AC-3): ask whether the source needs an env var; if yes, capture its **name** and verify it is **set and non-empty** in the current environment — STOP if missing/empty. `gh` is **not** checked.
    2. Probe (AC-4): execute the founder-supplied command, capture stdout, trim; result must be a single numeric value. Non-zero exit, empty, or non-numeric → STOP. State that the stored command string is **shell-expanded at probe time**, so any `$VAR` (including `$<Auth env var>`) resolves from the environment at run time — the value is never persisted. Note the command is founder-authored and runs locally with the founder's consent (cross-reference the command's Permissions & Trust Posture).

  - **Per-source auth/env + probe — Custom: endpoint**
    1. Env (AC-3): ask whether the source needs an env var (bearer token / PAT); if yes, capture its **name** and verify it is set and non-empty — STOP if missing/empty. `gh` is **not** checked. Also prompt for `Value path` (jq filter; default `.` = the raw body is already numeric).
    2. **jq availability gate (Minor 5b):** when the founder supplies a non-`.` `Value path` (i.e. jq extraction is actually required), verify `jq` is installed **before** probing; if `jq` is missing, STOP with a distinct message ("`jq` is required to extract `<Value path>` from the endpoint response — install `jq` and re-run, or supply a raw-numeric endpoint with `Value path` `.`"). A `Value path` of `.` needs no `jq` gate (the raw body is validated numeric directly).
    3. Probe (AC-4): `curl -fsS "<url>"` (fail on HTTP error), then apply `Value path` — **use `jq -r` (Minor 5e)** so the extracted value is raw text, not a JSON-quoted string, before numeric validation:
       ```bash
       curl -fsS "<url>" | jq -r '<Value path>'
       ```
       For `Value path` `.` with a plain-numeric body, the body itself is the value (still validated numeric). Connection error, HTTP error, empty, or non-numeric result → STOP.
    4. **Auth injection:** when `Auth env var` is set, add `-H "Authorization: Bearer $<name>"` (value read from the environment at run time, never persisted). The stored `<url>` is itself shell-expanded at probe time, so an embedded `$VAR` (e.g. `https://api.example.com/metric?token=$VAR`) resolves from the environment — covering query-param-token APIs that do not use a bearer header. State that any future reader (NA-9) MUST apply the same convention. Note that `curl` against a founder-supplied metric endpoint is legitimate — the "never hand-roll HTTP" rule applies to **Postiz**, not to the founder's own escape-hatch source.

  - **Numeric validation** — a probe result is valid iff, after trimming surrounding whitespace, it matches `^-?[0-9]+(\.[0-9]+)?$`. Anything else is a non-numeric failure → STOP. This validated value is recorded as `Verified value`.

  - **Collected model** — the ref outputs into the in-memory KPI model: `Metric name`, `Source type`, `Provider`, source-specific fields (`GitHub metric` / `Custom command` / `Custom endpoint` / `Value path`), `Auth env var` **name** (if any), and the probe's `Verified value`. Source-irrelevant fields are left blank.

  - **Error handling (own the STOP messages here)** — reproduce the spec's error table so the command references it rather than re-specifying it. Every STOP occurs in the gather phase (Step 4c) **before** the atomic Step 5, so no `marketing-context.md` change is written:
    | Scenario | STOP message intent | AC |
    | -------- | ------------------- | -- |
    | GitHub, `gh` not installed | install `gh` (or choose a custom source), then re-run; write nothing | AC-3/4 |
    | GitHub, `gh auth status` not authenticated | run `gh auth login`, then re-run; write nothing | AC-3/4 |
    | GitHub, `Repo` token not resolvable to `owner/name` | repo is not a GitHub `owner/name`; fix `Repo` or use a custom source; write nothing | AC-4 |
    | GitHub probe non-zero exit / non-numeric | could not read `<metric>` from `<owner>/<name>`; verify the repo exists and `gh` can reach it; write nothing | AC-4 |
    | Custom, named required env var missing/empty | env var `<NAME>` is not set; set it and re-run; write nothing | AC-3/4 |
    | Custom command non-zero exit / empty / non-numeric | the KPI command did not return a numeric value; write nothing | AC-4 |
    | Endpoint unreachable / HTTP error | could not reach `<url>`; write nothing | AC-4 |
    | Endpoint `Value path` non-`.` but `jq` missing | `jq` required to extract `<Value path>`; install `jq` or use a raw-numeric endpoint; write nothing | AC-4 |
    | Endpoint response not numeric after `Value path` | the endpoint response did not yield a numeric value at `<Value path>`; write nothing | AC-4 |
    | `Metric name` left blank | re-prompt — required (AC-1); never write a default | AC-1 |

- [ ] **Step 2: Self-check the ref** — the three source options, the `GitHub metric` enum + jq-field mapping, the numeric-validation regex, the `jq -r` endpoint extraction, the `jq`-availability gate, and the `open-issues`-includes-PRs caveat all appear and match the Global Constraints block verbatim. Confirm the file cites `gh`/`curl`/`jq` (never raw HTTP against Postiz) and that no unintended `<placeholder>` token remains beyond the intentional `<owner>/<name>`, `<url>`, `<name>`, `<metric>`, `<Value path>`, `<NAME>` illustration tokens.

---

### Task 2: Extend the template — `plugins/gtm/refs/marketing-context-template.md`

**Files:**
- Modify: `plugins/gtm/refs/marketing-context-template.md` (add `## KPI` to the fenced template block; add `## Schema` rows; add KPI fill rules)

**Interfaces:**
- Consumes: the locked source catalogue, enums, and field schema from Task 1 (must stay identical).
- Produces: the `## KPI` markdown table (nine fixed rows) + schema rows + fill rules that `commands/init.md` Step 5 renders into the staged `project/marketing-context.md`. Task 3's Step 5 edit renders exactly this table shape.

- [ ] **Step 1: Add the `## KPI` section to the fenced template block**, placed after the `## Channels` section and before the `## Voice` section. Use this exact nine-row shape (values illustrative only — the written file materialises the founder's real answers and the probe's real `Verified value`; source-irrelevant cells render **blank**):

```markdown
## KPI

| Token             | Value |
| ----------------- | ----- |
| Metric name       | GitHub stars |
| Source type       | managed |
| Provider          | github |
| GitHub metric     | stars |
| Custom command    |  |
| Custom endpoint   |  |
| Value path        |  |
| Auth env var      |  |
| Verified value    | 128 |
```

- [ ] **Step 2: Add a KPI secret-hygiene note** immediately under the `## KPI` fenced example (mirroring the Postiz section's secret-hygiene note): only the `Auth env var` **name** is persisted, never its value; the GitHub source persists no secret (ambient `gh` auth); `Custom command` / `Custom endpoint` strings are persisted verbatim and must reference an env var rather than embed a literal secret.

- [ ] **Step 3: Add KPI rows to the `## Schema` table** — one row per field, matching the spec's field schema exactly:

```markdown
| KPI | `Metric name` | string | Yes | none | Founder-named metric (AC-1). No plugin default — never pre-filled. |
| KPI | `Source type` | enum `managed` \| `custom` | Yes | none | AC-2. |
| KPI | `Provider` | enum `github` (when `managed`) \| `command` \| `endpoint` (when `custom`) | Yes | none | Managed → `github`; custom → the mechanism. |
| KPI | `GitHub metric` | enum `stars` \| `forks` \| `watchers` \| `open-issues` | When `Provider=github` | `stars` | Countable repo field. `open-issues` = `.open_issues_count`, which includes open PRs as well as issues. Blank for custom sources. |
| KPI | `Custom command` | string (shell command) | When `Provider=command` | none | Prints the metric's current value to stdout. Shell-expanded at probe time. Blank otherwise. |
| KPI | `Custom endpoint` | string (URL) | When `Provider=endpoint` | none | URL whose response contains the current value. Shell-expanded at probe time. Blank otherwise. |
| KPI | `Value path` | string (jq filter) | No | `.` | For `endpoint` JSON responses — jq filter (`.` = raw numeric body). Requires `jq` when non-`.`. Blank for `command`/`github`. |
| KPI | `Auth env var` | string (env var name) | No | blank | Env var **name** only — never the value. For the **endpoint** source, when set it is injected as `Authorization: Bearer $<name>` at probe time; embedded `$VAR` in a `command`/`endpoint` string is shell-expanded from the environment. Blank for `github`. |
| KPI | `Verified value` | string (numeric) | Yes | none | The one live value read by the Step-4c probe (AC-4). Refreshed on every Re-run/Merge re-probe. |
```

  > **Minor 5c (open-issues + PRs)** is captured in the `GitHub metric` row above.
  > **Minor 5f (scope Bearer-header note to endpoint):** the `Auth env var` row scopes the `Authorization: Bearer` injection specifically to the **endpoint** source; the `command`/`$VAR`-in-URL shell-expansion path is stated separately, so the bearer-header claim is not over-generalised to the command source.

- [ ] **Step 4: Add KPI fill rules** to the `## Fill rules` list — append these, continuing the numbering:
  - Materialise all nine `## KPI` rows — the row set is **fixed** and every row is always present; **source-irrelevant cells are written blank** (empty table cell), never omitted and never `<...>`.
  - `Metric name` is always the founder's real answer — never a default, never pre-filled (AC-1).
  - **Value path fill rule (Minor 5g):** `Value path` is written **blank** for the `github` and `command` sources (jq extraction does not apply); for the `endpoint` source it holds the founder's jq filter, and the literal `.` is written **only** when the endpoint body is already raw-numeric (`.` selects the whole body). Do not write `.` for non-endpoint sources — those cells are blank.
  - `Verified value` is always the probe's real trimmed numeric result — never invented, refreshed on every re-probe.
  - On the "Merge new findings" re-init path, preserve an already-set `## KPI` block; only backfill missing tokens.

---

### Task 3: Extend the command — `plugins/gtm/commands/init.md`

**Files:**
- Modify: `plugins/gtm/commands/init.md` (insert **Step 4c** after Step 4b; extend Step 0, Step 5, Step 6)

**Interfaces:**
- Consumes: `refs/kpi-config.md` (Task 1) applied by reference at Step 4c; the `## KPI` table shape + fill rules from the template (Task 2), rendered at Step 5; the Product `Repo` token resolved by the existing Step 3 detection.
- Produces: the extended `/gtm:init` command that gathers the KPI model in Step 4c and renders it into `marketing-context.md` in Step 5 — no new artifact consumed by other domain agents.

- [ ] **Step 1: Insert Step 4c — KPI metric and source**, immediately after Step 4b (Channel configuration) and before Step 5 (Write). It must state that, like Steps 4 and 4b, it **gathers into an in-memory KPI model and writes nothing to final paths** — Step 5 renders it. Delegate the detail to the new ref and enumerate the sub-steps:
  1. **Metric name (AC-1)** — prompt free-text for the metric that matters; no default, no pre-fill; required (blank → re-prompt).
  2. **Source selection (AC-2)** — `AskUserQuestion`, single-select: Managed: GitHub / Custom command / Custom endpoint.
  3. **Auth/env walk-through (AC-3)** — branch: GitHub → verify `gh` installed + `gh auth status` authenticated, resolve `<owner>/<name>` from the Product `Repo` token, prompt `GitHub metric` (default `stars`, noting the `open-issues`-includes-PRs caveat), no env-var prompt. Custom → prompt command/URL (+ `Value path` for endpoint), then ask whether an env var is needed and, if so, capture its **name** and verify it is set/non-empty; `gh` is **not** checked.
  4. **Verification probe (AC-4)** — read exactly one live numeric value per the ref's per-source probe. On any failure (missing/unauthenticated `gh`, unresolvable repo, missing named env var, missing `jq` when a non-`.` `Value path` is used, non-zero exit, unreachable endpoint, empty or non-numeric result) — **STOP with the matching clear error and write nothing.**
  5. **Collect** `Metric name`, `Source type`, `Provider`, source-specific fields, `Auth env var` name, and the probe's `Verified value` into the in-memory KPI model for Step 5.
  Add the **ordering invariant** note: Steps 4, 4b, 4c all write only in-memory; the sole config write is the atomic Step 5, so a probe STOP anywhere in 4c leaves every final path untouched — identical posture to the Step 2 Postiz gate. Cite the ref as `${CLAUDE_PLUGIN_ROOT}/refs/kpi-config.md` and defer STOP messages to it.

- [ ] **Step 2: Extend Step 0 (Re-init guard).** Add KPI handling to all three existing paths:
  - **Keep existing (Minor 5a)** — add a **KPI line** to the printed current-config summary (metric name, source type + provider, and `Verified value`, e.g. `KPI configured: "GitHub stars" via managed:github — verified value 128`), alongside the existing Product/Postiz/Channels summary lines, then STOP writing nothing.
  - **Merge new findings** — backfill the `## KPI` section only if absent; preserve an already-set KPI block. When present but incomplete, backfill only missing tokens (prompting for any missing user-choice field). **Malformed enum values on Merge (Minor 5d):** treat an existing KPI token holding an **invalid/out-of-enum value** (e.g. a `Source type` that is neither `managed` nor `custom`, or a `GitHub metric` outside the four-value enum) as **missing** — re-prompt for it rather than preserving the malformed value. Re-run the probe to refresh `Verified value`.
  - **Re-run full setup** — re-prompt all KPI fields with existing values offered as defaults, then re-run the probe.
  Both Merge and Re-run **re-enter the probe before writing** — a broken KPI source can never be re-written against (mirrors the Postiz gate re-entry posture).

- [ ] **Step 3: Extend Step 5 (Write).** Add an instruction to render the in-memory KPI model into the staged `marketing-context.md`'s `## KPI` section, fully materialised (all nine rows present; no `<...>` placeholder remains; source-irrelevant cells blank; `Value path` blank for non-endpoint sources per the Minor 5g fill rule). State that the KPI section is part of init's own atomic write and lands with the rest of `marketing-context.md`, which still moves **last** as the completion marker.

- [ ] **Step 4: Extend Step 6 (Post-init checklist).** Add a **KPI configured** line to the summary: metric name, source type + provider, and the `Verified value` read at init (e.g. `KPI configured: "GitHub stars" via managed:github — verified value 128`). Note the KPI can be changed by re-running `/gtm:init` (Merge/Re-run).

- [ ] **Step 5: Self-check the command edit** — Step 4c sits after 4b and before 5; the ref is cited as `${CLAUDE_PLUGIN_ROOT}/refs/kpi-config.md`; all three Step 0 paths address KPI (Keep summary line, Merge backfill + malformed-enum-as-missing, Re-run re-prompt); Step 5 renders the nine-row KPI section; Step 6 prints the KPI line. Confirm no pre-existing Postiz/channel step wording was altered.

---

### Task 4: Cross-file consistency verification

**Files:**
- Verify (read-only): `plugins/gtm/refs/kpi-config.md`, `plugins/gtm/refs/marketing-context-template.md`, `plugins/gtm/commands/init.md`

**Interfaces:**
- Consumes: all three edited files (Tasks 1–3).
- Produces: pass/fail signal — this repo has no typecheck/lint gate (Markdown + Shell), so verification is a Markdown cross-reference + enum/schema-consistency check.

- [ ] **Step 1: Cross-reference resolves** — confirm `init.md` cites `refs/kpi-config.md` and that the ref exists.

Run:
```bash
grep -n 'kpi-config.md' plugins/gtm/commands/init.md
test -f plugins/gtm/refs/kpi-config.md && echo "REF_EXISTS=yes"
```
Expected: at least one citation of `kpi-config.md` in `init.md`, and `REF_EXISTS=yes`.

- [ ] **Step 2: KPI token set is identical across the ref, template, and command** — the nine fixed tokens must read the same wherever named.

Run:
```bash
for f in plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md plugins/gtm/commands/init.md; do
  echo "== $f =="
  grep -onE 'Metric name|Source type|Provider|GitHub metric|Custom command|Custom endpoint|Value path|Auth env var|Verified value' "$f" | sort -u
done
```
Expected: the same token spellings appear in each file — no drift (e.g. `Metric name` vs `Metric`, `Auth env var` vs `Auth env`). Reconcile any mismatch.

- [ ] **Step 3: Enum + metric-mapping consistency** — the `Source type`, `Provider`, and `GitHub metric` enums and the jq-field mapping appear identically in the ref and template.

Run:
```bash
grep -rn 'stars.*forks.*watchers.*open-issues' plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md
grep -rn 'managed.*custom\|github.*command.*endpoint' plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md
grep -rn 'stargazers_count\|forks_count\|subscribers_count\|open_issues_count' plugins/gtm/refs/kpi-config.md
```
Expected: the `GitHub metric` enum (`stars`/`forks`/`watchers`/`open-issues`) and the `Source type`/`Provider` enums read identically across the ref and template; the four jq fields all appear in the ref's probe table. Manually reconcile any mismatch.

- [ ] **Step 4: Minor-item guards present** — confirm each folded-in Minor item is actually written.

Run:
```bash
grep -in 'jq -r' plugins/gtm/refs/kpi-config.md                                   # Minor 5e — raw jq extraction
grep -in 'jq.*install\|install.*jq\|jq is required\|requires .*jq' plugins/gtm/refs/kpi-config.md   # Minor 5b — jq gate
grep -in 'pull request\|includes .*PR\|open PRs\|as well as issues' plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md  # Minor 5c — open-issues caveat
grep -in 'Bearer' plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md      # Minor 5f — bearer scoped to endpoint
grep -in 'KPI configured\|verified value' plugins/gtm/commands/init.md            # Minor 5a — Keep-existing + Step 6 KPI line
grep -in 'malformed\|invalid.*enum\|out-of-enum\|treat.*as missing' plugins/gtm/commands/init.md     # Minor 5d — malformed enum on Merge
grep -in 'Value path' plugins/gtm/refs/marketing-context-template.md              # Minor 5g — blank-vs-. fill rule
```
Expected: every grep returns at least one hit in the named file(s). A miss means the corresponding Minor item was dropped — go back and add it before considering the task done.

- [ ] **Step 5: No stray placeholder tokens** — confirm no unintended `<...>` token remains in the three files beyond intentional template fill placeholders and illustration tokens (`<owner>/<name>`, `<url>`, `<name>`, `<metric>`, `<Value path>`, `<NAME>`, and the template's own `<...>` fill slots), plus init.md's pre-existing message placeholders (`<plugin>`, `<resolved>`, etc.).

Run:
```bash
grep -onE '<[^>]+>' plugins/gtm/refs/kpi-config.md plugins/gtm/refs/marketing-context-template.md plugins/gtm/commands/init.md
```
Expected: hits are only the intentional categories above. Investigate any token newly added by NA-5 that is not an illustration token or an intentional template fill placeholder.
