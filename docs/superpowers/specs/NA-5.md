# Set up KPI metric and source in init — Technical Spec

**Story:** [NA-5](https://whimzylive.atlassian.net/browse/NA-5)
**Epic:** [NA-2 — GTM marketing plugin for nightshift marketplace](https://whimzylive.atlassian.net/browse/NA-2)
**Date:** 2026-07-09

## Overview

Extends `/gtm:init` so the founder defines the one growth metric that matters to their product and
selects its source — a managed provider (GitHub at v1) or a custom command/endpoint — with a live
verification probe that reads one real value before any config is written. The resolved metric +
source is persisted to `.claude/project/marketing-context.md`; there is **no plugin-assumed
default metric**.

## Acceptance Criteria (from NA-5)

- **AC-1** — Founder names the metric that matters (no plugin-assumed default).
- **AC-2** — Founder chooses the metric's source: managed provider (GitHub) or a custom
  command/endpoint.
- **AC-3** — Init walks through the chosen source's auth/env needs (e.g. verifies `gh auth` **only**
  when GitHub is selected).
- **AC-4** — Init runs a verification probe that reads one live value from the chosen source
  **before** writing config; setup **STOPs with a clear error** if the probe fails.
- **AC-5** — The resolved KPI metric + source is written to `marketing-context.md`.

## Context & Scope Boundary

This story is a **Markdown/Shell plugin change** under `plugins/gtm/` — owned by the
`ai-enablement-engineer` per the project-context workspace→agent table. There is **no database, no
HTTP API, no web/mobile/offline-sync surface**; the "data model" is the `marketing-context.md`
config schema, and the "command surface" is the `/gtm:init` slash command. Sections that do not
apply to this stack (Data Model as ORM entities, API Surface, Web/Mobile/Offline Sync) are omitted
per the writing-specs skill.

### Dependency

- Depends on **NA-3** (`/gtm:init` base scaffold + `marketing-context.md` writer) and the existing
  init step order established by **NA-3/NA-4**. The KPI step slots into that flow as an additional
  gather step; it does not restructure the existing Postiz gate (Step 2), product-detect (Step 3),
  product-marketing (Step 4) or channel-config (Step 4b) steps.
- KPI setup is **independent of Postiz and channels** — the probe for the GitHub source uses the
  `gh` CLI, not Postiz.

### Provider catalogue (locked by this spec for v1)

| Source type | Provider / kind | Reads value via | Notes |
| ----------- | --------------- | --------------- | ----- |
| `managed`   | `github`        | `gh api repos/<owner>/<name>` | Only managed provider at v1 (epic: "GitHub is the only managed provider at v1"). Repo resolved from the Product `Repo` token. |
| `custom`    | `command`       | Execute a founder-supplied shell command; read stdout | Universal escape hatch — any product, any metric. |
| `custom`    | `endpoint`      | HTTP GET a founder-supplied URL; extract via value path | Universal escape hatch for HTTP metric sources. |

Further managed providers are **deferred and demand-driven** (epic Resolved Decisions) — out of
scope here.

## Config Schema — `marketing-context.md` KPI section

A new `## KPI` section is rendered into `.claude/project/marketing-context.md` by `/gtm:init`
Step 5, and added to `plugins/gtm/refs/marketing-context-template.md`. It follows the existing
`| Token | Value |` table convention used by the Postiz section.

### New section (rendered form)

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

The row set is **fixed** (all nine tokens always present); source-irrelevant cells are written
**blank**, mirroring how the template renders "blank allowed" cells today. Values above are
illustrative — the written file materialises the founder's real answers and the probe's real
`Verified value`.

### Field schema (added to the template's `## Schema` table)

| Section | Field | Type | Required | Default | Notes |
| ------- | ----- | ---- | -------- | ------- | ----- |
| KPI | `Metric name` | string | Yes | **none** | Founder-named metric (AC-1). No plugin default — never pre-filled. |
| KPI | `Source type` | enum `managed` \| `custom` | Yes | none | AC-2. |
| KPI | `Provider` | enum `github` (when `managed`) \| `command` \| `endpoint` (when `custom`) | Yes | none | Managed → `github`; custom → the mechanism (`command`/`endpoint`). |
| KPI | `GitHub metric` | enum `stars` \| `forks` \| `watchers` \| `open-issues` | When `Provider=github` | `stars` | Which countable repo field to read; `stars` is the suggested default because the founder has actively chosen the GitHub source (not a metric-name default — AC-1 is satisfied by `Metric name`). Blank for custom sources. |
| KPI | `Custom command` | string (shell command) | When `Provider=command` | none | Command that prints the metric's current value to stdout. Blank otherwise. |
| KPI | `Custom endpoint` | string (URL) | When `Provider=endpoint` | none | URL whose response contains the metric's current value. Blank otherwise. |
| KPI | `Value path` | string (jq filter) | No | `.` | For `endpoint` JSON responses — jq filter that extracts the numeric value (`.` = the raw body is already numeric). Blank for `command`/`github`. |
| KPI | `Auth env var` | string (env var **name**) | No | blank | Name of an env var the custom source needs (bearer token, PAT, etc.). **Name only — never the value.** **Injection convention:** when set, the probe (and any future reader, e.g. NA-9) sends `Authorization: Bearer $<name>` with the value read from the environment at run time; the stored `Custom command`/`Custom endpoint` strings are also shell-expanded at run time, so any `$VAR` reference embedded in them (e.g. `?token=$VAR`) resolves from the environment. Blank for `github` (which uses `gh`'s own auth) and for custom sources needing no auth. |
| KPI | `Verified value` | string (numeric) | Yes | none | The one live value read by the Step-4c probe (AC-4) — a provenance breadcrumb proving the source worked at init. Refreshed on every Re-run/Merge re-probe. |

### Secret hygiene

Consistent with the Postiz section: **only env-var names are persisted** (`Auth env var`), never
values. The GitHub source persists **no secret at all** — it relies on the ambient `gh` CLI auth.
`Custom command` / `Custom endpoint` strings are persisted verbatim; the founder must not embed a
literal secret in them (they should reference an env var read at run time). This is stated as a note
in the rendered section.

## Command Surface — `/gtm:init` changes

### Step 4c — KPI metric and source (new)

Insert a new **Step 4c** immediately after Step 4b (Channel configuration) and before Step 5
(Write). Like Steps 4 and 4b, it **gathers into an in-memory KPI model and writes nothing to final
paths** — Step 5 renders it. The new step delegates its detail to a new ref
`${CLAUDE_PLUGIN_ROOT}/refs/kpi-config.md` (see below), and does the following:

1. **Metric name (AC-1)** — prompt the founder (free-text) for the metric that matters. No default,
   no pre-fill. Required — cannot be left blank.
2. **Source selection (AC-2)** — `AskUserQuestion`, single-select:
   - **Managed: GitHub** — read a repo metric via the `gh` CLI (only managed provider at v1).
   - **Custom command** — run a shell command that prints the current value.
   - **Custom endpoint** — HTTP GET a URL that returns the current value.
3. **Auth/env walk-through (AC-3)** — branch on the choice:
   - **GitHub** → verify `gh` is installed **and** `gh auth status` reports authenticated. Resolve
     `<owner>/<name>` from the Product `Repo` token. Prompt for the `GitHub metric` (default
     `stars`). No env-var prompt.
   - **Custom command/endpoint** → prompt for the command / URL (+ `Value path` for endpoint), then
     ask whether the source needs an env var; if yes, capture its **name** and verify it is set and
     non-empty in the current environment. `gh` is **not** checked.
4. **Verification probe (AC-4)** — read exactly **one** live value from the chosen source (see
   `kpi-config.md` for the per-source probe). The value must be numeric. On any failure — missing
   `gh`/`gh` not authed, unresolvable repo, missing named env var, non-zero exit, unreachable
   endpoint, empty or non-numeric result — **STOP with the matching clear error and write nothing.**
5. **Collect** `Metric name`, `Source type`, `Provider`, source-specific fields, `Auth env var`
   name, and the probe's `Verified value` into the in-memory KPI model for Step 5.

**Ordering invariant (the AC-4 "write nothing" guarantee):** Steps 4, 4b and 4c all write only to
in-memory models; the sole config write is the atomic Step 5. A probe STOP anywhere in Step 4c
therefore leaves every final path untouched — identical posture to the Step 2 Postiz gate.

### Step 0 — Re-init guard (extend)

- **Merge new findings** — backfill the `## KPI` section only if absent from the existing file;
  preserve an already-set KPI block. When present but incomplete, backfill only missing tokens
  (prompting for any missing user-choice field). Re-run the probe to refresh `Verified value`.
- **Re-run full setup** — re-prompt all KPI fields with existing values offered as defaults, then
  re-run the probe.
- Both paths **re-enter the probe before writing** — a broken KPI source can never be re-written
  against, mirroring the Postiz gate's re-entry posture.

### Step 5 — Write (extend)

Render the in-memory KPI model into the staged `marketing-context.md`'s new `## KPI` section, fully
materialised (no `<...>` placeholder token remains; source-irrelevant cells blank). The KPI section
is part of init's own atomic config write — it lands with the rest of `marketing-context.md`, which
still moves **last** (the completion marker).

### Step 6 — Post-init checklist (extend)

Add a **KPI configured** line to the summary: metric name, source type + provider, and the
`Verified value` read at init (e.g. `KPI configured: "GitHub stars" via managed:github — verified
value 128`). Note that the KPI can be changed by re-running `/gtm:init` (Merge/Re-run).

## New Ref — `plugins/gtm/refs/kpi-config.md`

A new protocol ref, structured like `channel-config.md` / `postiz-verify.md`, that `/gtm:init`
Step 4c applies exactly. It MUST specify:

### Source selection prompt

The `AskUserQuestion` shape (three options above) and the rule that `Metric name` is captured first,
free-text, with no default (AC-1).

### Per-source auth/env + probe

**Managed: GitHub**

1. Auth (AC-3): require `gh` installed and `gh auth status` authenticated. STOP with a distinct
   message on either failure.
2. Resolve `<owner>/<name>` from the Product `Repo` token (normalised `owner/name`). If the token is
   a non-GitHub URL or unresolvable to `owner/name`, STOP.
3. Probe (AC-4) — read one value via a single `gh api` call, mapped by `GitHub metric`:

   | GitHub metric | jq field on `repos/<owner>/<name>` |
   | ------------- | ---------------------------------- |
   | `stars`       | `.stargazers_count` |
   | `forks`       | `.forks_count` |
   | `watchers`    | `.subscribers_count` |
   | `open-issues` | `.open_issues_count` |

   ```bash
   gh api "repos/<owner>/<name>" --jq '.stargazers_count'
   ```

   Non-zero exit or non-numeric output → STOP.

**Custom: command**

1. Env (AC-3): if the founder named a required env var, verify it is set and non-empty; STOP if
   missing.
2. Probe (AC-4): execute the command, capture stdout, trim; must be a single numeric value. Non-zero
   exit, empty, or non-numeric → STOP. (The command is founder-authored and runs locally with the
   founder's consent — see Permissions & Trust Posture.) The stored command string is shell-expanded
   at probe time, so any `$VAR` reference in it (including `$<Auth env var>`) resolves from the
   environment at run time — the value is never persisted.

**Custom: endpoint**

1. Env (AC-3): if the founder named a required env var (bearer token / PAT), verify it is set and
   non-empty; STOP if missing.
2. Probe (AC-4): `curl -fsS "<url>"` (fail on HTTP error), then apply `Value path` (jq for JSON;
   `.` = raw numeric body). Result must be numeric. Connection error, HTTP error, empty, or
   non-numeric → STOP. (Curl against a founder-supplied metric endpoint is legitimate — the "never
   hand-roll HTTP" rule applies to **Postiz**, not to the founder's own escape-hatch source.)
   **Auth injection:** when `Auth env var` is set, the probe adds
   `-H "Authorization: Bearer $<name>"`, the value read from the environment at run time and never
   persisted. The stored `<url>` string is itself shell-expanded at probe time, so any `$VAR`
   reference embedded in it (e.g. `https://api.example.com/metric?token=$VAR`) resolves from the
   environment — covering query-param-token APIs that do not use a bearer header. Any future reader
   of this config (e.g. NA-9's KPI reader) MUST apply the same injection convention.

### Numeric validation

A probe result is valid iff, after trimming surrounding whitespace, it matches
`^-?[0-9]+(\.[0-9]+)?$`. Anything else is a non-numeric failure → STOP.

### Error handling (defer to ref, mirror channel-config.md)

The ref owns the STOP messages; the command references it rather than re-specifying them.

## Deliverables

| # | Artifact | Change | Owner |
| - | -------- | ------ | ----- |
| 1 | `plugins/gtm/refs/kpi-config.md` | **New** — KPI setup protocol (selection, per-source auth/env, probe, numeric validation, error table). | ai-enablement-engineer |
| 2 | `plugins/gtm/commands/init.md` | **Modify** — add Step 4c; extend Step 0 (re-init), Step 5 (write), Step 6 (checklist); reference the new ref. | ai-enablement-engineer |
| 3 | `plugins/gtm/refs/marketing-context-template.md` | **Modify** — add the `## KPI` section, its `## Schema` rows, and KPI fill rules. | ai-enablement-engineer |

No changes to `tools/` (platform-engineer) or `brand/` (web-engineer). `plugin.json`,
`load-marketing-context.sh`, and scripts are unaffected.

## Error Handling

| Scenario | Behaviour | AC |
| -------- | --------- | -- |
| GitHub source, `gh` not installed | STOP: install `gh` (or choose a custom source), then re-run. Write nothing. | AC-3/4 |
| GitHub source, `gh auth status` not authenticated | STOP: run `gh auth login`, then re-run. Write nothing. | AC-3/4 |
| GitHub source, `Repo` token not resolvable to `owner/name` | STOP: repo is not a GitHub `owner/name`; fix the `Repo` token or use a custom source. Write nothing. | AC-4 |
| GitHub probe `gh api` non-zero exit / non-numeric | STOP: could not read `<metric>` from `<owner>/<name>`; verify the repo exists and `gh` can reach it. Write nothing. | AC-4 |
| Custom source, named required env var missing/empty | STOP: env var `<NAME>` is not set; set it and re-run. Write nothing. | AC-3/4 |
| Custom command non-zero exit / empty / non-numeric | STOP: the KPI command did not return a numeric value. Write nothing. | AC-4 |
| Custom endpoint unreachable / HTTP error | STOP: could not reach `<url>`. Write nothing. | AC-4 |
| Custom endpoint response not numeric after `Value path` | STOP: the endpoint response did not yield a numeric value at `<Value path>`. Write nothing. | AC-4 |
| `Metric name` left blank | Re-prompt — the metric name is required (AC-1); never write a default. | AC-1 |

**Write-nothing scope:** every KPI STOP occurs in Step 4c (gather phase) before the atomic Step 5,
so no `marketing-context.md` change is written. As with channel-config, Step 4's product-marketing
skill may already have (re)written `.agents/product-marketing.md`; that is unrelated to the KPI
config and is not rolled back — re-running `/gtm:init` heals a half-run.

## Permissions & Trust Posture

- **No secrets persisted** — only env-var **names** (`Auth env var`) reach disk; the GitHub source
  persists no secret (uses ambient `gh` auth). Custom command/endpoint strings must reference env
  vars rather than embed literal secrets; the rendered section states this. At probe time the named
  env var is injected as `Authorization: Bearer $<name>` (endpoint) or shell-expanded from the
  stored string (command / `$VAR` in URL), always read live from the environment.
- **Custom-command execution** — the probe executes a **founder-supplied shell command** locally,
  during an interactive `/gtm:init` the founder explicitly initiated and to which they typed the
  command. This is the intended escape-hatch behaviour; init does not sandbox or sanitise it. No new
  privilege boundary is crossed (same trust level as any command the founder runs in their own
  repo).
- **Single-tenant, local config** — there is no multi-tenant/org isolation surface here; the plugin
  writes one repo-local config file for the repo's own owner.

## Out of Scope

- Optional **engagement-source** configuration and polling (NA-11 — separate story; explicitly out
  of scope per NA-5).
- **KPI reporting / correlation / growth report** (NA-9 — separate story).
- **Additional managed providers** beyond GitHub (deferred, demand-driven per epic).
- **Historical KPI time-series** storage / scheduling — the probe reads exactly one value at init as
  a verification check, not a recurring measurement.
- **UTM correlation convention** between KPI and published content (epic-level, not this story).
- Any change under `tools/` or `brand/`, or to plugin functionality outside `/gtm:init` KPI setup.

## Open Questions (all resolved — defaults locked by this spec)

- [x] **Which GitHub metrics does v1 offer?** — Locked: `stars`, `forks`, `watchers`, `open-issues`
  (the four countable fields on `repos/<owner>/<name>`, readable in one `gh api` call). Default
  selection `stars`.
- [x] **Custom-endpoint value extraction** — Locked: a `Value path` jq filter (default `.` = raw
  numeric body); JSON responses use a jq path, plain-numeric bodies use `.`.
- [x] **Custom-source auth** — Locked: a single optional `Auth env var` **name** (bearer token /
  PAT), value read from the environment at run time, never persisted; injected as
  `Authorization: Bearer $<name>` (or via `$VAR` shell-expansion in the stored URL/command for
  query-param-token APIs).
- [x] **Persist the probe's value?** — Locked: yes, as `Verified value` (provenance breadcrumb;
  refreshed on every re-probe).
- [x] **Step placement** — Locked: Step 4c, after channel config, before the atomic Step 5. All 4x
  steps write only to in-memory models, so a probe STOP leaves the repo untouched regardless of
  order.

## Decided (defaults locked by this spec)

- No plugin-assumed **metric name** default — the founder always names it (AC-1).
- v1 source catalogue: `managed:github` + `custom:command` + `custom:endpoint` — no other managed
  provider.
- `gh` auth is checked **only** when the GitHub source is selected (AC-3); custom sources never
  trigger a `gh` check.
- The KPI probe reads exactly **one** value and must be numeric; any failure STOPs init before the
  atomic write (AC-4), writing nothing.
- KPI config is part of init's own atomic Step-5 write; `marketing-context.md` moves last as the
  completion marker (unchanged from NA-3).
