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

## Triage

| Token                                           | Value |
| ----------------------------------------------- | ----- |
| Lightweight threshold (story points, inclusive) | `3`   |

## Code Review

| Token        | Value           |
| ------------ | --------------- |
| Review agent | `claude-inline` |
| Review mode  | `on-create`     |
