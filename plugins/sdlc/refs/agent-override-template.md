# Agent Override Template

This file is the canonical template for `.claude/project/agents/<agent>.md`.
`/init` Step 4c generates one file per active domain agent by filling the
token slots below. Overrides carry directory guides, ownership and rules; skills live in
`.claude/project/skills.json`. No placeholder tokens (`<...>`) may remain in the generated
files — every slot must be replaced with an actual value.

---

## Template

```markdown
# <Agent display name> — <project name> bindings

## Directory guides (read before coding)

<list each owned-path CLAUDE.md file that exists, e.g.: - <owned-path>/CLAUDE.md>
<if none exist yet, write: # No directory guides yet — add CLAUDE.md files to owned paths.>

## Ownership

- owns: <this agent's confirmed owned path(s)>
- never: <all other agents' owned paths — list them explicitly>
- runs after: <upstream agent in pipeline or "—"> · before: <downstream agent or "—">

## Tech rules

- Language: <DETECTED_LANG>, strict mode — no `any`, no unsafe casts.
- Framework: <DETECTED_FRAMEWORK> (or "none detected" if framework is none).
- Runtime: <DETECTED_RUNTIME> (omit this line if no runtime was detected).
- Commit scopes: <DETECTED_COMMIT_SCOPES> — use only these conventional-commit scopes (omit this line if none derived).
- File naming: kebab-case for all source files.
- Import order: external packages → internal aliases → relative paths → type-only imports.
- <Add any repo-specific "always do X / never do Y" rules the user confirms.>

## Local dev (tokens from project-context Tooling)

- Typecheck: `<confirmed typecheck cmd>` · Test: `<confirmed test cmd>`
- Never run cloud deploys — those are manual ops actions outside agent scope.
```

---

## Run-order table

Use this table to populate the `runs after / before` line in `## Ownership`.
Only list the upstream/downstream agents that are **active in this repo**. If
an agent has no active upstream, write `—`; if no active downstream, write `—`.

| Agent | Runs after | Runs before |
| --- | --- | --- |
| `database-administrator` | — | `platform-engineer`, `sync-engineer` |
| `platform-engineer` | `database-administrator` | `sync-engineer`, `web-engineer`, `mobile-engineer` |
| `sync-engineer` | `database-administrator`, `platform-engineer` | `web-engineer`, `mobile-engineer` |
| `web-engineer` | `platform-engineer`, `sync-engineer` | — |
| `mobile-engineer` | `platform-engineer`, `sync-engineer` | — |

---

## Skills

An override does not list skills. `.claude/project/skills.json` (`refs/skills-manifest.md`) names the
skills each agent uses and when, and the dispatch prompt carries them (`scripts/skills-for.sh`).

## Designer notes

The `designer` override records the board lint rules, page template names and the bundle sync
recipe in `## Tech rules`. `web-engineer` and `mobile-engineer` overrides keep construction rules
only (layering, Storybook keyboard tests, bundle membership, accessibility, fidelity-gate operation)
and never restate the design decision rules (reuse/extend/new, shadcn parts for a new pattern,
restyling), which belong to `designer`.

Do not write override files for agents the user did not select.
