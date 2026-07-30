# Benchmark: NA-82

Cost is split by phase. `impl-only` is the comparable figure across approaches;
`review + fix` and `ceremony` are what the process-heavy approaches additionally buy.

| Status  | Approach    | Version  | impl-only API-eq $ | review + fix API-eq $ | ceremony API-eq $ | total API-eq $ | Regressions | ACs met | findings | wall clock |
| ------- | ----------- | -------- | -----------------: | --------------------: | ----------------: | -------------: | ----------- | ------- | -------- | ---------- |
| NO DIFF | sdlc@0.45.4 | 0.45.4 ? |                  — |                     — |                 — |           0.00 | no          | —       | —        | 0.0s       |
| NO DIFF | sdlc@0.45.4 | 0.45.4 ? |                  — |                     — |                 — |           2.38 | no          | —       | —        | 449.9s     |
| FAILED  | sdlc@0.45.4 | 0.45.4   |                  — |                     — |                 — |          11.54 | no          | 0/0     | 0        | 1642.5s    |

Billing mode: **subscription**. no API key present (checked ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN and 3 settings file(s)) -- `claude` authenticates via the operator's Claude subscription, so reported cost figures are API-list-price equivalents for the tokens consumed, not per-run spend.

Dollar columns are **API-equivalents**: what the tokens consumed would cost at
API list price. They are not a bill. On a subscription run **no per-run charge is
incurred** — no money leaves an account. The comparison across approaches still
holds regardless, because every approach is priced against the same rate card.

## What each cell loaded

Every plugin not listed below was **explicitly disabled** in the cell's
worktree, overriding both the repository's committed settings and the
operator's own. Without that, a cell inherits whatever the operator had
enabled and its label describes a session it did not have.

| Approach    | Plugins enabled                                                                                   |
| ----------- | ------------------------------------------------------------------------------------------------- |
| sdlc@0.45.4 | `sdlc@nightshift`                                                                                 |
| sdlc@0.45.4 | `sdlc@nightshift`, `claude-mem@thedotmack` _(dep)_, `superpowers@claude-plugins-official` _(dep)_ |

### Hooks that ran regardless

Hooks declared in user or repository settings merge additively across settings
layers and cannot be switched off from a project file, so these ran inside every
measured session. They are a confound on every row equally — which does not make
them harmless, since a hook that rewrites commands or injects text changes the
tokens this benchmark counts.

- `PreToolUse` — `rtk hook claude`

## Version provenance

A pinned version is verified against the session transcript, not against the
adapter that requested it: plugins announce their resolved root from a hook
inside the resolved directory, so the announcement is evidence that directory
executed. `!` in the Version column means the pin did **not** take and the row
measures a different version than the one requested — the column shows what
actually ran. `?` means the pin could not be confirmed either way, because that
plugin announces no root, so the label rests on the declaration alone.

- **sdlc@0.45.4**: sdlc@nightshift was pinned to 0.45.4, but the session transcript carries no plugin-root announcement for it, so the version rests on the declaration alone and could not be independently confirmed.
- **sdlc@0.45.4**: sdlc@nightshift was pinned to 0.45.4, but the session transcript carries no plugin-root announcement for it, so the version rests on the declaration alone and could not be independently confirmed.

## Failed reconciliations

The following rows failed reconciliation (reconstructed per-phase cost drifted past 2% tolerance).
Their per-phase figures are omitted from the comparison. **Do not use these rows for cost analysis.**

- **sdlc@0.45.4**: computed cost drifted past tolerance; excluded from aggregates
- **sdlc@0.45.4**: computed cost drifted past tolerance; excluded from aggregates
- **sdlc@0.45.4**: computed cost drifted past tolerance; excluded from aggregates

## Phase attribution unavailable

These rows declared more than one phase, but **no phase marker matched anywhere in
the transcript** — so every entry defaulted into whichever phase was declared first
and the whole run's spend landed in one bucket. That is an artefact of the
attribution rule, not a measurement, so the impl-only / review + fix / ceremony
split is shown as `—`. **The total $ column is still valid** — only the split is not.

This is what happens when an approach's phases run inline inside one session rather
than being triggered by literal slash commands the marker regex can see.

- **sdlc@0.45.4**: phase attribution unavailable: 5 phases declared (spec, plan, impl, review-fix, docs) but no phase marker matched anywhere in the transcript, so every entry defaulted to the first declared phase. The per-phase split for this row is an artefact, not a measurement.

## Failed cells — no code change

These cells ran a measured session and produced an **empty diff** against their base
commit. There is nothing to grade, so ACs and findings are shown as `—` rather than
as a clean `0/0` with 0 findings. **These are failed cells, not good results.**
The usual cause is the session being unable to commit (missing Bash permission), or
the model finishing without writing anything.

- **sdlc@0.45.4**: no code change: `git diff 1c8bb837571187e93ceb63124d829c3906163259..HEAD` in /Users/Rushi/Development/EdgeTech/ai-workspace/nightshift/.bench-worktrees/NA-82-sdlc@0.45.4-r1 is empty. The measured session ran but committed nothing, so there is nothing to grade. The session made 0 Edit and 0 Write tool call(s) -- if those are non-zero the work was done but never committed (check that the worktree's .claude/settings.local.json grants Bash(git commit:\*)); if they are zero the session produced no work at all.
- **sdlc@0.45.4**: no code change: `git diff 1c8bb837571187e93ceb63124d829c3906163259..HEAD` in /Users/Rushi/Development/EdgeTech/ai-workspace/nightshift/.bench-worktrees/NA-82-sdlc@0.45.4-r2 is empty. The measured session ran but committed nothing, so there is nothing to grade. The session made 1 Edit and 2 Write tool call(s) -- if those are non-zero the work was done but never committed (check that the worktree's .claude/settings.local.json grants Bash(git commit:\*)); if they are zero the session produced no work at all.
