# KPI Metric and Source Setup Protocol

Used by `/gtm:init` Step 4c — the KPI metric-name/source-selection/verification-probe picker. This
step only **gathers values into an in-memory KPI model**; it writes nothing to any final path
(`/gtm:init` Step 5 renders the model into `marketing-context.md`).

## Source selection prompt

Capture **`Metric name` first** — free-text, no default, required (AC-1). A blank answer
**re-prompts**; the plugin never assumes a metric on the founder's behalf.

Then `AskUserQuestion`, single-select, three options:

```
AskUserQuestion(
  header: "KPI source",
  question: "Where should this metric's live value be read from?",
  multiSelect: false,
  options: [
    { label: "Managed: GitHub",  description: "Read a repo metric (stars/forks/watchers/open-issues) via the gh CLI." },
    { label: "Custom command",   description: "Run a shell command that prints the current value to stdout." },
    { label: "Custom endpoint",  description: "HTTP GET a URL that returns the current value." }
  ]
)
```

Record the resolved `Source type` (`managed` | `custom`) and `Provider` (`github` when `managed`;
`command` | `endpoint` when `custom`).

## Per-source auth/env + probe — Managed: GitHub

1. **Auth (AC-3):** require `gh` installed **and** `gh auth status` authenticated. STOP with a
   **distinct** message on each failure (install `gh` / run `gh auth login`) — see Error handling.
2. **Resolve the repo:** derive `<owner>/<name>` from the Product `Repo` token (normalise to
   `owner/name`). If the token is a non-GitHub URL or otherwise unresolvable to `owner/name`, STOP.
3. **Prompt `GitHub metric`** — single-select `stars` \| `forks` \| `watchers` \| `open-issues`,
   default `stars`. **Caveat:** state that `open-issues` maps to `.open_issues_count`,
   which includes open **pull requests** as well as issues — a founder who wants an issues-only
   count should know `open-issues` is really an issues+PRs count. No env-var prompt for GitHub.
4. **Probe (AC-4):** read one value via a single `gh api` call, mapped by `GitHub metric`:

   | GitHub metric | jq field on `repos/<owner>/<name>` |
   | ------------- | ---------------------------------- |
   | `stars`       | `.stargazers_count`                |
   | `forks`       | `.forks_count`                     |
   | `watchers`    | `.subscribers_count`               |
   | `open-issues` | `.open_issues_count`               |

   ```bash
   gh api "repos/<owner>/<name>" --jq '.stargazers_count'
   ```

   Non-zero exit or non-numeric output → STOP.

## Per-source auth/env + probe — Custom: command

1. **Env (AC-3):** ask whether the source needs an env var; if yes, capture its **name** and verify
   it is **set and non-empty** in the current environment — STOP if missing/empty. `gh` is **not**
   checked for custom sources.
2. **Probe (AC-4):** execute the founder-supplied command, capture stdout, trim; the result must be
   a single numeric value. Non-zero exit, empty, or non-numeric output → STOP. The stored command
   string is **shell-expanded at probe time**, so any `$VAR` reference embedded in it (including
   `$<Auth env var>`) resolves from the environment at run time — the value is never persisted.
   The command is founder-authored and runs locally with the founder's own consent (see the
   command's Permissions & Trust Posture) — this is the intended escape-hatch behaviour, not a new
   privilege boundary.

## Per-source auth/env + probe — Custom: endpoint

1. **Env (AC-3):** ask whether the source needs an env var (bearer token / PAT); if yes, capture
   its **name** and verify it is set and non-empty — STOP if missing/empty. `gh` is **not** checked.
   Also prompt for `Value path` (jq filter; default `.` = the raw body is already numeric).
2. **jq availability gate:** when the founder supplies a non-`.` `Value path` (i.e. jq
   extraction is actually required), verify `jq` is installed **before** probing. If `jq` is
   missing, STOP:

   > `jq` is required to extract `<Value path>` from the endpoint response — install `jq` and
   > re-run, or supply a raw-numeric endpoint with `Value path` `.`.

   A `Value path` of `.` needs no `jq` gate — the raw body is validated numeric directly.

3. **Probe (AC-4), with auth injection applied inline:** the `Authorization` header (when needed)
   must be attached to the **same** `curl` call that reads the value — never added after the fact,
   or an authed endpoint 401s and STOPs before any later step is reached. When `Auth env var` is
   set, every `curl` invocation below adds `-H "Authorization: Bearer $<name>"` (the value read
   from the environment at run time, never persisted). The stored `<url>` is itself shell-expanded
   at probe time too, so an embedded `$VAR` (e.g. `https://api.example.com/metric?token=$VAR`)
   resolves from the environment — covering query-param-token APIs that don't use a bearer header;
   when a URL uses that pattern, no `-H` flag is needed. Any future reader of this config (e.g.
   NA-9's KPI reader) MUST apply the same injection convention. Curl against a founder-supplied
   metric endpoint is legitimate here — the "never hand-roll HTTP" rule applies to **Postiz**, not
   to the founder's own escape-hatch source.

   Which of the two forms below applies is exactly the same condition as the jq availability gate
   in step 2 — `jq` is only invoked when `Value path` is non-`.`:
   - **`Value path` = `.`** (raw-numeric body, the common case for a from-scratch metric endpoint):
     validate the response body numeric directly — no `jq` involved, so this form works even when
     `jq` isn't installed:

     ```bash
     curl -fsS "<url>"
     # with an Auth env var set:
     curl -fsS -H "Authorization: Bearer $<name>" "<url>"
     ```

   - **`Value path` is non-`.`** (extracting a numeric field from a JSON response): pipe through
     `jq -r` — use `jq -r`, not plain `jq`, so the extracted value is raw text, not a JSON-quoted
     string, before numeric validation. `jq`'s presence was already confirmed by step 2's gate:

     ```bash
     curl -fsS "<url>" | jq -r '<Value path>'
     # with an Auth env var set:
     curl -fsS -H "Authorization: Bearer $<name>" "<url>" | jq -r '<Value path>'
     ```

   Connection error, HTTP error, empty, or non-numeric result (either form) → STOP.

## Numeric validation

A probe result is valid iff, after trimming surrounding whitespace, it matches
`^-?[0-9]+(\.[0-9]+)?$`. Anything else is a non-numeric failure → STOP. This validated value is
recorded as `Verified value`.

## Collected model

The ref outputs into the in-memory KPI model: `Metric name`, `Source type`, `Provider`,
source-specific fields (`GitHub metric` / `Custom command` / `Custom endpoint` / `Value path`),
`Auth env var` **name** (if any), and the probe's `Verified value`. Source-irrelevant fields are
left blank.

## Secret hygiene

Only env-var **names** (`Auth env var`) reach disk — never values. The GitHub source persists no
secret at all (it relies on ambient `gh` CLI auth). `Custom command` / `Custom endpoint` strings are
persisted verbatim and must reference an env var rather than embed a literal secret — the rendered
`marketing-context.md` section states this.

## Error handling

Every STOP below occurs in the gather phase (Step 4c), **before** the atomic Step 5, so no
`marketing-context.md` change is written:

| Scenario                                            | Behaviour                                                                                                           | AC     |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------ |
| GitHub, `gh` not installed                          | STOP: install `gh` (or choose a custom source), then re-run. Write nothing.                                         | AC-3/4 |
| GitHub, `gh auth status` not authenticated          | STOP: run `gh auth login`, then re-run. Write nothing.                                                              | AC-3/4 |
| GitHub, `Repo` token not resolvable to `owner/name` | STOP: repo is not a GitHub `owner/name`; fix the `Repo` token or use a custom source. Write nothing.                | AC-4   |
| GitHub probe non-zero exit / non-numeric            | STOP: could not read `<metric>` from `<owner>/<name>`; verify the repo exists and `gh` can reach it. Write nothing. | AC-4   |
| Custom, named required env var missing/empty        | STOP: env var `<NAME>` is not set; set it and re-run. Write nothing.                                                | AC-3/4 |
| Custom command non-zero exit / empty / non-numeric  | STOP: the KPI command did not return a numeric value. Write nothing.                                                | AC-4   |
| Endpoint unreachable / HTTP error                   | STOP: could not reach `<url>`. Write nothing.                                                                       | AC-4   |
| Endpoint `Value path` non-`.` but `jq` missing      | STOP: `jq` required to extract `<Value path>`; install `jq` or use a raw-numeric endpoint. Write nothing.           | AC-4   |
| Endpoint response not numeric after `Value path`    | STOP: the endpoint response did not yield a numeric value at `<Value path>`. Write nothing.                         | AC-4   |
| `Metric name` left blank                            | Re-prompt — required (AC-1); never write a default.                                                                 | AC-1   |

This table mirrors the spec's Error Handling section, plus the jq-availability gate row (a
hardening addition not present in the spec) — `/gtm:init` Step 4c cites this ref rather than
re-specifying the messages.
