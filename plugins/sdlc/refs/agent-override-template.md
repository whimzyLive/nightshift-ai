# Agent Override Template

This file is the canonical template for `.claude/project/agents/<agent>.md`.
`/init` Step 4c generates one file per active domain agent by filling the
token slots below. No placeholder tokens (`<...>`) may remain in the generated
files — every slot must be replaced with an actual value.

---

## Template

```markdown
# <Agent display name> — <project name> bindings

## Project skills (invoke in order via the Skill tool)
<list each confirmed skill relevant to this agent's domain, one per line, numbered>
<if no skills are relevant to this agent, write: # No project skills configured yet.>

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

## Agent domain mapping

Use this table to filter the confirmed install list (from Step 3.5) to skills
relevant to each agent. The authoritative per-skill domain list is in
`refs/skills-map.yml` (each skill's `domains` array). This table is a quick
reference summary; do not duplicate or diverge the skill assignments here.

| Agent | Relevant skill domains |
| ----- | ---------------------- |
| `platform-engineer` | API/backend skills: `hono-api`, `api-routes`, `typeorm`, and any custom backend skills |
| `web-engineer` | Frontend skills: `react-components`, `vercel-react-best-practices`, `vercel-composition-patterns` |
| `mobile-engineer` | Mobile skills: any custom mobile skills; no built-in suggestions map here |
| `database-administrator` | ORM/migration skills: `typeorm`, and any custom DB skills |
| `sync-engineer` | Sync-layer skills: no built-in suggestions; any custom sync skills |

---

## Run-order table

Use this table to populate the `runs after / before` line in `## Ownership`.
Only list the upstream/downstream agents that are **active in this repo**. If
an agent has no active upstream, write `—`; if no active downstream, write `—`.

| Agent | Runs after | Runs before |
| ----- | ---------- | ----------- |
| `database-administrator` | — | `platform-engineer`, `sync-engineer` |
| `platform-engineer` | `database-administrator` | `sync-engineer`, `web-engineer`, `mobile-engineer` |
| `sync-engineer` | `database-administrator`, `platform-engineer` | `web-engineer`, `mobile-engineer` |
| `web-engineer` | `platform-engineer`, `sync-engineer` | — |
| `mobile-engineer` | `platform-engineer`, `sync-engineer` | — |

---

## Per-agent filtering rules

When populating `## Project skills` for a given agent:

1. Start from the confirmed install list produced in Step 3.5.
2. Retain only skills whose `domains` array (in `refs/skills-map.yml`) includes
   this agent's name.
3. If no confirmed skills are relevant, write the placeholder comment:
   `# No project skills configured yet.`
4. Do not write override files for agents the user did not select.
