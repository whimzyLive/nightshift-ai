# Triage protocol

Complexity routing for SDLC commands: a story is **lightweight** (no spec, implement directly) or **full** (a spec the user approves in session first). `scripts/triage.sh` is the implementation; this ref describes the rules it applies. Callers run the script and route on its output: they never compute the route, look up the threshold or probe the points themselves.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/triage.sh <KEY> [ISSUE_TYPE]
```

## Inputs

- `<KEY>` — a Jira story key. The project key lives in `.claude/project/project-context.md`, never fetched via acli.
- `<ISSUE_TYPE>` — optional issue-type name (e.g. `bug`, `story`). When the caller already has it (`/auto` passes its Step-0 `ITYPE`) the script makes zero extra Jira calls for it; otherwise it fetches it.

## Work-kind derivation (defect vs feature)

The issue is a **defect** (Bug) or a **feature** (everything else), from `issuetype.name`, input-or-fetch. The script fetches it with the one-liner `commands/auto.md` Step 0 uses; the `// empty` and the lower-casing are load-bearing there.

- lower-cases to `bug` → `WORK_KIND=defect`
- any other type, **or** an unreadable/empty value → `WORK_KIND=feature` (**fail-safe**: no positive Bug signal never routes a feature into the debugging path)

The check is on the issue-type string only; it does not read points, labels or any custom field.

> **Known limitation (accepted, not net-new).** The predicate is a literal case-insensitive
> `issuetype.name == "bug"` compare. `refs/jira-fetch.md` notes that literal issue-type-name matching is
> per-instance fragile (a renamed/localized Bug type — "Defect", a translation — would not match) and
> prefers JQL type functions where possible. This protocol keeps the literal compare **deliberately**:
> it mirrors `commands/auto.md` Step 0's existing convention exactly (single-sourcing the predicate is
> the priority). Hardening the Bug-type signal plugin-wide (a JQL `issuetype in (...)` form) is out of
> scope — it would change the established Step-0 convention and belongs in its own change.

## Threshold resolution (AC-4)

The lightweight threshold `T` is configurable, first match wins:

1. **Per-repo override** in `.claude/project/project-context.md` — an optional `## Triage` section with the token row `Lightweight threshold (story points, inclusive)` holding an integer:

   ```markdown
   ## Triage

   | Token                                           | Value |
   | ----------------------------------------------- | ----- |
   | Lightweight threshold (story points, inclusive) | `<N>` |
   ```

2. **Built-in default `3`** when the section or token is absent.

A present but non-integer token is ignored: `T = 3` plus a `WARNING:` line. The script reads the file itself (from a linked worktree it falls back to the primary checkout's copy) and prints the value it used as `THRESHOLD=<T>`, so a wrong route is visible in the transcript. No environment variable and no separate config file.

## Story-point reading

The script follows `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` "Reading story points": JQL-probe BOTH the `Story point estimate` and `Story Points` field names (retrying across index lag), then candidate-probe the value on the populated field. `missing` only when neither field is populated; a set field whose value is outside the candidate list, or any acli error, exits non-zero rather than reporting `missing`. It never trusts `fields.customfield_*` from the view JSON.

## Decision table

Threshold `T` (default `3`); lightweight uses an **inclusive upper bound** — exactly `T` points is lightweight.
The **Bug row is highest priority and overrides the points threshold unconditionally** — an 8-point Bug
is still `lightweight` (defects skip the spec):

| Condition | `WORK_KIND` | `TRIAGE` | Notes |
| --- | --- | --- | --- |
| `issuetype` is Bug | `defect` | `lightweight` | **forced** — overrides points; highest priority |
| `points <= T` (non-Bug) | `feature` | `lightweight` | inclusive upper bound (exactly `T` ⇒ lightweight) |
| `points > T` (non-Bug) | `feature` | `full` | approved spec required |
| `points` missing (non-Bug) | `feature` | `full` | fail-safe default; also emit a `WARNING:` line |

A defect with `STORY_POINTS=missing` still reports `STORY_POINTS=missing` honestly on its line, but
`TRIAGE=lightweight` — the missing-points fail-safe-to-`full` rule applies to **features only**.

## Output contract

The script prints a deterministic, machine-parseable block. The three `=` lines are **always emitted (required)**; the `WARNING:` line is **optional** and appears only in the degraded cases (missing points, malformed threshold); a final `THRESHOLD=<T>` line reports the threshold used:

```
WARNING: <message>           # optional — only on missing points / malformed threshold
WORK_KIND=defect|feature     # required
TRIAGE=lightweight|full      # required
STORY_POINTS=N|missing       # required
THRESHOLD=<T>                # informational — the threshold the decision used
```

Callers MUST route on the `WORK_KIND=`/`TRIAGE=`/`STORY_POINTS=` lines only and MUST ignore the `WARNING:` and `THRESHOLD=` lines for
routing. `WORK_KIND=` is the **new** third required line (defect-vs-feature classification — see
**Work-kind derivation**); it is emitted alongside the unchanged `TRIAGE=`/`STORY_POINTS=` lines, so
existing two-line parsers stay back-compatible. `STORY_POINTS=` carries the same meaning as scrum-master Mode 3's line, so existing parsers are reused; `TRIAGE=` is a dedicated key distinct from scrum-master's `QUALITY=` (quality/refinement is a different concern from complexity routing).

## Error handling

| Scenario | Behaviour | Result |
| --- | --- | --- |
| `issuetype` is Bug | force the lightweight defect path, regardless of points | `WORK_KIND=defect`, `TRIAGE=lightweight` |
| `issuetype.name` unreadable/empty | fail-safe to feature — never route a feature into the debugging path | `WORK_KIND=feature` (then point-based `TRIAGE`) |
| `points <= T` (non-Bug) | route lightweight | `TRIAGE=lightweight` |
| `points > T` (non-Bug) | route full | `TRIAGE=full` |
| `points` unset (`missing`, non-Bug) | fail-safe to the full path; emit a warning to set points before running lightweight `/impl` (AC-5) | `TRIAGE=full`, `STORY_POINTS=missing`, plus a `WARNING:` line |
| `acli` Jira fetch fails (auth/DNS) | **STOP** — never guess a route; surface the acli error to the caller. Triage must never silently default to a route when Jira is unreachable; emit no `WORK_KIND=`/`TRIAGE=` block. | non-zero / explicit STOP message |
| threshold token malformed/non-numeric in project-context | ignore the override, use the built-in default `3`, and emit a warning | `TRIAGE` computed against `T = 3` |

## Warning line format

On its own line, prefixed `WARNING:`, so parsers that consume only `TRIAGE=`/`STORY_POINTS=` are unaffected. Worked example for the missing-points case:

```
WARNING: Story points not set on <KEY> — defaulting to the full (approved-spec) path. Set points in Jira before running /impl for the lightweight path.
WORK_KIND=feature
TRIAGE=full
STORY_POINTS=missing
```

(A Bug never reaches this warning: `WORK_KIND=defect` forces `TRIAGE=lightweight` even with
`STORY_POINTS=missing`, and the missing-points fail-safe is feature-only.)
