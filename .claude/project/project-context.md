# Project Context

| Token            | Value                        |
| ---------------- | ---------------------------- |
| Project name     | nightshift-ai                |
| Jira project key | NA                           |
| Jira site        | whimzylive.atlassian.net     |
| Base branch      | main                         |
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

| Path                | Owner                  |
| ------------------- | ---------------------- |
| plugins/            | ai-enablement-engineer |
| skills/             | ai-enablement-engineer |
| .agents/            | ai-enablement-engineer |
| tools/              | platform-engineer      |
| brand/              | web-engineer           |
| apps/marketing/     | web-engineer           |
| apps/marketing-e2e/ | web-engineer           |
| packages/ui/        | web-engineer           |

## Tooling

| Test | `pnpm nx run-many -t test` |

## Triage

| Token                                           | Value |
| ----------------------------------------------- | ----- |
| Lightweight threshold (story points, inclusive) | `3`   |

## Code Review

| Token        | Value                |
| ------------ | -------------------- |
| Review agent | `claude-superpowers` |
| Review mode  | `on-update`          |
