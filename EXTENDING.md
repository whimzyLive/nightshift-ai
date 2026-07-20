# Extending nightshift — teach the agents your stack

You almost never fork nightshift. The agents are deliberately generic — you teach them your tech
stack from **your own repo**, through two project-tier files plus any skills you write. The generic
agents stay untouched and keep getting upstream updates.

Each domain agent, at startup, does this:

1. reads `.claude/project/project-context.md` (constants, tooling, the workspace→agent ownership table);
2. reads its **override** `.claude/project/agents/<agent>.md` — and **invokes every project skill that file lists, in order, via the Skill tool**, then reads the directory guides it points to.

So extending an agent = **write a skill + name it in the override.** Three steps.

## 1. Add a skill (your stack's know-how)

Drop it in your repo at `.claude/skills/<name>/SKILL.md`:

```markdown
---
name: my-orm
description: How we model entities, write migrations, and query with <your ORM>.
---

When writing data-access code in this project:

- Entities live in `src/db/entities/*.ts`; one file per entity.
- Every migration is generated, never hand-written: `npm run db:generate`.
- Always scope queries by `tenantId`. Never return cross-tenant rows.
```

Skills can be anything an agent should _pull in on demand_: an ORM convention, an API-routing
pattern, a design system, a deployment recipe. Skills from **any** installed plugin work too —
just reference them by name.

## 2. Bind the skill to an agent (the override)

Create `.claude/project/agents/<agent>.md` (e.g. `platform-engineer.md`). This is the contract the
generic agent reads:

```markdown
# Platform Engineer — <your-project> bindings

## Project skills (invoke in order via the Skill tool)

1. my-orm
2. my-api-patterns # only when touching HTTP routes

## Directory guides (read before coding)

- src/db/CLAUDE.md
- src/api/CLAUDE.md

## Ownership

- owns: src/api/, src/db/
- never: src/web/ (web-engineer)
- runs after: database-administrator · before: web-engineer

## Tech rules

- <Framework + runtime>, TypeScript strict, no `any`, kebab-case files.
- <Any "always do X / never do Y" your codebase enforces.>

## Local dev (tokens from project-context Tooling)

- Build: `<your build cmd>` · Test: `<your test cmd>` · never run cloud deploys.
```

The agent invokes `my-orm` and `my-api-patterns` via the Skill tool at runtime, reads your
directory guides, and confines itself to your owned paths — all without editing the shipped agent.

## 3. Declare ownership + tooling once (project-context)

In `.claude/project/project-context.md`, the **workspace→agent** table is the single source of
truth for who owns what, and the **Tooling** rows define the quality gate every agent runs:

```markdown
## Workspace → agent

| Path     | Owner             |
| -------- | ----------------- |
| src/api/ | platform-engineer |
| src/web/ | web-engineer      |

## Tooling

| Typecheck | `npm run typecheck` |
| Test | `npm test` |
```

## Patterns

- **New tech, existing role** → add a skill + list it in that role's override. (Most common.)
- **Same role, different conventions per repo** → just change the override; the generic agent is reused as-is.
- **Activate a standby role** (mobile, sync, db) → mark it Active in project-context and give it an override.
- **A brand-new role** (e.g. `ml-engineer`) → fork the marketplace, add `agents/ml-engineer.md` to the plugin, and `/plugin marketplace update`. PRs for broadly useful roles are welcome.

> Rule of thumb: **project-specific knowledge → your repo's `.claude/` (skills + overrides + project-context). Generic role behavior → the plugin.** Keep that line clean and upgrades never fight your customizations.

## A note on plugin versions

Never hand-edit a plugin's `.claude-plugin/plugin.json` `version` field. It's managed by
`nx release`, driven by your conventional commits — see [CONTRIBUTING.md's "Releasing"
section](CONTRIBUTING.md#releasing) for the commit contract, the release commands, and the
one-time baseline-tag backfill.
