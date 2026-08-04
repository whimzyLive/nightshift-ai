# Project Context

| Token            | Value                        |
| ---------------- | ---------------------------- |
| Project name     | nightshift-ai                |
| Jira project key | NA                           |
| Jira site        | whimzylive.atlassian.net     |
| Base branch      | develop                      |
| Package manager  | pnpm                         |
| Typecheck / Test | — / pnpm nx run-many -t test |

## Detected stack

| Signal           | Detected value           |
| ---------------- | ------------------------ |
| Primary language | TypeScript               |
| Framework(s)     | Next.js                  |
| Package manager  | pnpm                     |
| Test runner      | pnpm nx run-many -t test |

## Workspace → agent

| Path                                                  | Owner                                                              |
| ----------------------------------------------------- | ------------------------------------------------------------------ |
| plugins/                                              | ai-enablement-engineer                                             |
| skills/                                               | ai-enablement-engineer                                             |
| .agents/                                              | ai-enablement-engineer                                             |
| agents/, .codex/, .opencode/, .gemini/, opencode.json | ai-enablement-engineer (nx-generated mirrors — machine-maintained) |
| tools/                                                | platform-engineer                                                  |
| .github/                                              | platform-engineer                                                  |
| brand/                                                | web-engineer                                                       |
| apps/marketing/                                       | web-engineer                                                       |
| apps/marketing-e2e/                                   | web-engineer                                                       |
| packages/ui/                                          | web-engineer                                                       |

## Tooling

| Test | `pnpm nx run-many -t test` |
| Shared Nx cache | `<repo-root>/.nx/cache` (absolute path; the primary checkout's cache — do NOT mutate committed `nx.json`) |
| SDLC agent reuse | `enabled` |

`SDLC agent reuse` scopes to impl-phase fix rounds only (QA Engineer playbook Step 3): `enabled`
reuses the domain agent that ran the phase across its fix-round dispatches instead of a fresh
`Agent(...)` each round; `disabled` is the documented off-switch, restoring a fresh dispatch every
round.

## Memory

| Token                   | Value      |
| ----------------------- | ---------- |
| Review retention window | `6 months` |

## Triage

| Token                                           | Value |
| ----------------------------------------------- | ----- |
| Lightweight threshold (story points, inclusive) | `5`   |

## Code Review

| Token        | Value           |
| ------------ | --------------- |
| Review agent | `claude-inline` |
| Review mode  | `on-update`     |

## CI

| Token        | Value |
| ------------ | ----- |
| Max attempts | `5`   |

`Max attempts` is the per-step retry ceiling used by `tools/ci-retry.sh`, which wraps every check
step in `.github/workflows/ci.yml`. A step that exits non-zero is re-run until it passes or the
ceiling is reached; the final failure's exit status is what CI sees. Set it to `1` to disable
retrying entirely.

**Retrying does not make a failing gate pass.** Nearly every step here is a deterministic shell
suite — it fails identically on all 5 attempts and just costs 5x the wall-clock. The steps this
genuinely helps are the network-bound ones (`pnpm install`, `playwright install`, registry and Nx
cache fetches), where a transient DNS/502/rate-limit blip is the whole failure. If a _test_ suite
ever needs a retry to go green, that is a flaky test to fix, not a step to re-run.

## Pipeline

| Token                | Value  |
| -------------------- | ------ |
| Pipeline done status | `Done` |
