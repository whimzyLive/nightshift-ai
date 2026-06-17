# Triage protocol

Shared complexity-routing protocol for SDLC commands. Reference this from any command that needs to decide whether a story is **lightweight** (skip the spec+plan ceremony, implement directly) or **full** (spec + plan review gate required before implementation). This is the single source of truth for the threshold, the decision table, and the missing-points handling — `/triage`, `/auto`, and `/impl` all reference it rather than re-stating the logic.

## Inputs

- `<KEY>` — a Jira story key, e.g. `ED-100`, `CER-123`. The project key lives in `.claude/project/project-context.md` — never fetch it via acli.

## Threshold resolution (AC-4)

The lightweight threshold `T` MUST be configurable, not hard-coded. Resolution order, **first match wins**:

1. **Per-repo override** in `.claude/project/project-context.md` — an optional `## Triage` section with a token row `Lightweight threshold (story points, inclusive)` holding an integer:
   ```markdown
   ## Triage

   | Token | Value |
   | ----- | ----- |
   | Lightweight threshold (story points, inclusive) | `3` |
   ```
2. **Built-in default `3`** when the section or token is absent.

If the override token is present but **non-numeric / malformed**, ignore it, fall back to `T = 3`, and emit a `WARNING:` line (see Error handling).

`.claude/project/project-context.md` is already the mandated first read for every SDLC command, so resolving `T` adds no new file read. No environment variable and no separate config file — configuration stays in the one project-context file, matching every other per-repo SDLC constant.

## Story-point reading (reused, not reinvented)

Read the story's points via the existing `${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md` **"Reading story points"** protocol: JQL-probe BOTH the `Story point estimate` and `Story Points` field names, then candidate-probe the value on the populated field. Report `missing` **only** when neither field name is populated. Do **not** duplicate the probe loop here — reference the ref. Do **not** trust `fields.customfield_*` from the view JSON (ids vary by instance).

## Decision table

Threshold `T` (default `3`); lightweight uses an **inclusive upper bound** — exactly `T` points is lightweight:

| Story points | `TRIAGE` | Notes |
| ------------ | -------- | ----- |
| `points <= T` | `lightweight` | inclusive upper bound (exactly `T` ⇒ lightweight) |
| `points > T` | `full` | spec + plan required |
| `missing` | `full` | fail-safe default; also emit a `WARNING:` line |

## Output contract

The protocol returns a deterministic, machine-parseable block. The two `=` lines are **always emitted (required)**; the `WARNING:` line is **optional** and appears only in the degraded cases (missing points, malformed threshold):

```
WARNING: <message>           # optional — only on missing points / malformed threshold
TRIAGE=lightweight|full      # required
STORY_POINTS=N|missing       # required
```

Callers MUST route on the two required lines only and MUST ignore the optional `WARNING:` line for routing. `STORY_POINTS=` carries the same meaning as scrum-master Mode 3's line, so existing parsers are reused; `TRIAGE=` is a dedicated key distinct from scrum-master's `QUALITY=` (quality/refinement is a different concern from complexity routing).

## Error handling

| Scenario | Behaviour | Result |
| -------- | --------- | ------ |
| `points <= T` | route lightweight | `TRIAGE=lightweight` |
| `points > T` | route full | `TRIAGE=full` |
| `points` unset (`missing`) | fail-safe to the full path; emit a warning to set points before running lightweight `/impl` (AC-5) | `TRIAGE=full`, `STORY_POINTS=missing`, plus a `WARNING:` line |
| `acli` Jira fetch fails (auth/DNS) | **STOP** — never guess a route; surface the acli error to the caller. Triage must never silently default to a route when Jira is unreachable. | non-zero / explicit STOP message |
| threshold token malformed/non-numeric in project-context | ignore the override, use the built-in default `3`, and emit a warning | `TRIAGE` computed against `T = 3` |

## Warning line format

On its own line, prefixed `WARNING:`, so parsers that consume only `TRIAGE=`/`STORY_POINTS=` are unaffected. Worked example for the missing-points case:

```
WARNING: Story points not set on <KEY> — defaulting to the full (spec+plan) path. Set points in Jira before running /impl for the lightweight path.
TRIAGE=full
STORY_POINTS=missing
```
