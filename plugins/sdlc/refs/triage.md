# Triage protocol

Shared complexity-routing protocol for SDLC commands. Reference this from any command that needs to decide whether a story is **lightweight** (skip the spec+plan ceremony, implement directly) or **full** (spec + plan review gate required before implementation). This is the single source of truth for the threshold, the decision table, and the missing-points handling — `/triage`, `/auto`, and `/impl` all reference it rather than re-stating the logic.

## Inputs

- `<KEY>` — a Jira story key, e.g. `ED-100`, `CER-123`. The project key lives in `.claude/project/project-context.md` — never fetch it via acli.
- `<ISSUE_TYPE>` — **optional** lower-cased issue-type name (e.g. `bug`, `story`). When the caller already
  has it (the `/auto` inline path threads its Step-0 `ITYPE`), pass it in so this protocol derives
  `WORK_KIND` with **zero extra Jira I/O**. When absent (standalone `/impl`, `/triage`), the protocol
  fetches it itself — see **Work-kind derivation**.

## Work-kind derivation (defect vs feature)

The protocol classifies the issue as a **defect** (Bug) or a **feature** (everything else) and emits
`WORK_KIND=defect|feature`. This is derived from the issue's `issuetype.name`, **input-or-fetch**:

- **Input handed in** (`<ISSUE_TYPE>` provided) → use it directly; do **not** re-fetch (the `/auto`
  inline path already fetched it at Step 0 — re-fetching would double the per-story `acli` round-trips
  on the autonomous worker's hottest entry path).
- **No input** (standalone `/impl`, `/triage`) → fetch with the **exact** canonical one-liner
  `commands/auto.md` Step 0 uses — reproduce it verbatim, do **not** write a divergent variant:
  ```bash
  acli jira workitem view <KEY> --fields issuetype --json | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]'
  ```
  The `// empty` and `tr '[:upper:]' '[:lower:]'` are load-bearing: without `// empty` an unreadable
  type yields the literal string `null` (not empty) and the fail-safe-to-`feature` mis-fires; without
  the `tr` an `issuetype.name` of `Bug` fails the lowercase `bug` compare.

Classify by comparing the (already lower-cased) type to `bug`:

- lower-cases to `bug` → `WORK_KIND=defect`
- any other type, **or** an unreadable/empty value → `WORK_KIND=feature` (**fail-safe**: the absence of
  a positive Bug signal must never route a feature into the debugging path)

The check is purely on the issue-type string — it does not read points, labels, or any custom field.

> **Known limitation (accepted, not net-new).** The predicate is a literal case-insensitive
> `issuetype.name == "bug"` compare. `refs/jira-fetch.md` notes that literal issue-type-name matching is
> per-instance fragile (a renamed/localized Bug type — "Defect", a translation — would not match) and
> prefers JQL type functions where possible. This protocol keeps the literal compare **deliberately**:
> it mirrors `commands/auto.md` Step 0's existing convention exactly (single-sourcing the predicate is
> the priority). Hardening the Bug-type signal plugin-wide (a JQL `issuetype in (...)` form) is out of
> scope — it would change the established Step-0 convention and belongs in its own change.

## Threshold resolution (AC-4)

The lightweight threshold `T` MUST be configurable, not hard-coded. Resolution order, **first match wins**:

1. **Per-repo override** in `.claude/project/project-context.md` — an optional `## Triage` section with a token row `Lightweight threshold (story points, inclusive)` holding an integer:

   ```markdown
   ## Triage

   | Token                                           | Value |
   | ----------------------------------------------- | ----- |
   | Lightweight threshold (story points, inclusive) | `3`   |
   ```

2. **Built-in default `3`** when the section or token is absent.

If the override token is present but **non-numeric / malformed**, ignore it, fall back to `T = 3`, and emit a `WARNING:` line (see Error handling).

`.claude/project/project-context.md` is already the mandated first read for every SDLC command, so resolving `T` adds no new file read. No environment variable and no separate config file — configuration stays in the one project-context file, matching every other per-repo SDLC constant.

## Story-point reading (reused, not reinvented)

Read the story's points via the existing `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` **"Reading story points"** protocol: JQL-probe BOTH the `Story point estimate` and `Story Points` field names, then candidate-probe the value on the populated field. Report `missing` **only** when neither field name is populated. Do **not** duplicate the probe loop here — reference the ref. Do **not** trust `fields.customfield_*` from the view JSON (ids vary by instance).

## Decision table

Threshold `T` (default `3`); lightweight uses an **inclusive upper bound** — exactly `T` points is lightweight.
The **Bug row is highest priority and overrides the points threshold unconditionally** — an 8-point Bug
is still `lightweight` (defects skip spec+plan):

| Condition                  | `WORK_KIND` | `TRIAGE`      | Notes                                             |
| -------------------------- | ----------- | ------------- | ------------------------------------------------- |
| `issuetype` is Bug         | `defect`    | `lightweight` | **forced** — overrides points; highest priority   |
| `points <= T` (non-Bug)    | `feature`   | `lightweight` | inclusive upper bound (exactly `T` ⇒ lightweight) |
| `points > T` (non-Bug)     | `feature`   | `full`        | spec + plan required                              |
| `points` missing (non-Bug) | `feature`   | `full`        | fail-safe default; also emit a `WARNING:` line    |

A defect with `STORY_POINTS=missing` still reports `STORY_POINTS=missing` honestly on its line, but
`TRIAGE=lightweight` — the missing-points fail-safe-to-`full` rule applies to **features only**.

## Output contract

The protocol returns a deterministic, machine-parseable block. The two `=` lines are **always emitted (required)**; the `WARNING:` line is **optional** and appears only in the degraded cases (missing points, malformed threshold):

```
WARNING: <message>           # optional — only on missing points / malformed threshold
WORK_KIND=defect|feature     # required
TRIAGE=lightweight|full      # required
STORY_POINTS=N|missing       # required
```

Callers MUST route on the required `=` lines only and MUST ignore the optional `WARNING:` line for
routing. `WORK_KIND=` is the **new** third required line (defect-vs-feature classification — see
**Work-kind derivation**); it is emitted alongside the unchanged `TRIAGE=`/`STORY_POINTS=` lines, so
existing two-line parsers stay back-compatible. `STORY_POINTS=` carries the same meaning as scrum-master Mode 3's line, so existing parsers are reused; `TRIAGE=` is a dedicated key distinct from scrum-master's `QUALITY=` (quality/refinement is a different concern from complexity routing).

## Error handling

| Scenario                                                 | Behaviour                                                                                                                                                                           | Result                                                        |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `issuetype` is Bug                                       | force the lightweight defect path, regardless of points                                                                                                                             | `WORK_KIND=defect`, `TRIAGE=lightweight`                      |
| `issuetype.name` unreadable/empty                        | fail-safe to feature — never route a feature into the debugging path                                                                                                                | `WORK_KIND=feature` (then point-based `TRIAGE`)               |
| `points <= T` (non-Bug)                                  | route lightweight                                                                                                                                                                   | `TRIAGE=lightweight`                                          |
| `points > T` (non-Bug)                                   | route full                                                                                                                                                                          | `TRIAGE=full`                                                 |
| `points` unset (`missing`, non-Bug)                      | fail-safe to the full path; emit a warning to set points before running lightweight `/impl` (AC-5)                                                                                  | `TRIAGE=full`, `STORY_POINTS=missing`, plus a `WARNING:` line |
| `acli` Jira fetch fails (auth/DNS)                       | **STOP** — never guess a route; surface the acli error to the caller. Triage must never silently default to a route when Jira is unreachable; emit no `WORK_KIND=`/`TRIAGE=` block. | non-zero / explicit STOP message                              |
| threshold token malformed/non-numeric in project-context | ignore the override, use the built-in default `3`, and emit a warning                                                                                                               | `TRIAGE` computed against `T = 3`                             |

## Warning line format

On its own line, prefixed `WARNING:`, so parsers that consume only `TRIAGE=`/`STORY_POINTS=` are unaffected. Worked example for the missing-points case:

```
WARNING: Story points not set on <KEY> — defaulting to the full (spec+plan) path. Set points in Jira before running /impl for the lightweight path.
WORK_KIND=feature
TRIAGE=full
STORY_POINTS=missing
```

(A Bug never reaches this warning: `WORK_KIND=defect` forces `TRIAGE=lightweight` even with
`STORY_POINTS=missing`, and the missing-points fail-safe is feature-only.)
